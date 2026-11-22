# Single entry point for every listing search: web pages, saved-searches,
# alerts and the future API. Controllers only translate HTTP params into the
# permitted hash and render the Result.
class ListingSearch
  PER_PAGE = 24
  MAX_PAGE = 100
  MAX_QUERY_LENGTH = 100
  MAX_FILTER_VALUES = 24
  SORTS = %w[best_match newest price_asc price_desc popular].freeze
  SHIPPING_OPTIONS = %w[ship pickup].freeze
  COUNT_CACHE_TTL = 60.seconds
  FACETS_CACHE_TTL = 5.minutes

  SearchFilter = Struct.new(:key, :value, :label, :remove_params, keyword_init: false)

  INCLUDES = [
    :store, :category, :region, :user,
    { images_attachments: { blob: { variant_records: { image_attachment: :blob } } } }
  ].freeze

  attr_reader :category, :base

  def initialize(params: {}, category: nil, base: Listing.visible)
    @params = normalise_hash(params)
    @category = category
    @base = base
  end

  def result
    @result ||= Result.new(self)
  end

  def relation
    @relation ||= apply_sort(build_relation(include_specs: true, include_condition: true,
                                            include_secondary: true))
                  .includes(*INCLUDES)
  end

  def self.bust_caches!
    Rails.cache.write("listing_search/version", Time.current.to_f)
  end

  def self.cache_version
    Rails.cache.fetch("listing_search/version", expires_in: 1.day) { 0.0 }
  end

  def total_count
    @total_count ||= Rails.cache.fetch(total_cache_key, expires_in: COUNT_CACHE_TTL) do
      relation.except(:order).count
    end
  end

  def active_filters
    @active_filters ||= build_active_filters
  end

  def facets
    @facets ||= Rails.cache.fetch(facets_cache_key, expires_in: FACETS_CACHE_TTL) do
      compute_facets
    end
  end

  def condition_counts
    @condition_counts ||= build_relation(include_specs: true, include_condition: false,
                                         include_secondary: true).except(:order).group(:condition).count
  end

  def query
    @query ||= @params[:q].to_s.strip.first(MAX_QUERY_LENGTH).presence
  end

  def min_price_cents
    @min_price_cents ||= cents_from_euros(@params[:min_price])
  end

  def max_price_cents
    @max_price_cents ||= cents_from_euros(@params[:max_price])
  end

  def conditions
    @conditions ||= Array(@params[:condition]).map(&:to_s) & Listing.conditions.keys
  end

  def labels
    @labels ||= Array(@params[:labels]).map(&:to_s) & Listing::LABELS
  end

  def tags
    @tags ||= Array(@params[:tags]).map(&:to_s) & Listing::TAGS
  end

  def spec_filters
    @spec_filters ||= begin
      raw = @params[:f]
      raw = {} unless raw.respond_to?(:to_h)

      raw.to_h.each_with_object({}) do |(key, values), result|
        key = key.to_s
        next unless filter_keys.include?(key)

        selected = Array(values).map { |value| value.to_s.strip.first(80) }
                                .reject(&:blank?).uniq.first(MAX_FILTER_VALUES)
        result[key] = selected if selected.any?
      end
    end
  end

  def region_ids
    @region_ids ||= Array(@params[:region_id]).map(&:to_i).select(&:positive?).uniq.first(MAX_FILTER_VALUES)
  end

  def shipping
    @shipping ||= Array(@params[:shipping]).map(&:to_s) & SHIPPING_OPTIONS
  end

  def free_shipping?
    @free_shipping ||= truthy?(@params[:free_shipping])
  end

  def on_sale?
    @on_sale ||= truthy?(@params[:on_sale]) || truthy?(@params[:deals])
  end

  def seller
    @seller ||= @params[:seller].to_s.strip.first(80).presence
  end

  def sort
    @sort ||= begin
      candidate = @params[:sort].to_s
      candidate = (query.present? ? "best_match" : "newest") unless SORTS.include?(candidate)
      candidate
    end
  end

  def page
    @page ||= begin
      value = @params[:page].to_i
      value = 1 if value < 1
      [ value, MAX_PAGE ].min
    end
  end

  # Spec filters only make sense inside a category: the category is what
  # defines which FilterDefinitions are effective.
  def filter_definitions
    @filter_definitions ||= category ? category.effective_filters : []
  end

  def category_ancestors
    @category_ancestors ||= category ? category.path.to_a : []
  end

  def category_parent
    category_ancestors[-2]
  end

  def child_categories
    @child_categories ||= category ? category.children.active.order(:position, :id).to_a : []
  end

  def regions
    @regions ||= Region.where(country_code: "ES").order(:name).to_a
  end

  def filter_keys
    @filter_keys ||= filter_definitions.map(&:key)
  end

  def query_params
    base_params
  end

  def normalized_params
    {
      q: query,
      category_id: category&.id,
      min_price_cents: min_price_cents,
      max_price_cents: max_price_cents,
      condition: conditions,
      labels: labels,
      tags: tags,
      specs: spec_filters,
      region_ids: region_ids,
      shipping: shipping,
      free_shipping: free_shipping?,
      on_sale: on_sale?,
      seller: seller,
      sort: sort,
      page: page
    }
  end

  def digest
    @digest ||= Digest::SHA256.hexdigest(normalized_params.deep_stringify_keys.sort.to_s)
  end

  private

  def normalise_hash(raw)
    hash = raw.respond_to?(:to_h) ? raw.to_h : {}
    ActiveSupport::HashWithIndifferentAccess.new(hash)
  end

  def build_relation(include_specs:, include_condition:, include_secondary:, facets_only: false)
    scope = base
    scope = scope.merge(Listing.in_category(category)) if category
    scope = scope.search_text(query) if query.present?
    scope = apply_spec_filters(scope) if include_specs
    scope = scope.where(condition: conditions) if include_condition && conditions.any?
    scope = apply_price_range(scope)

    if include_secondary && !facets_only
      scope = scope.where("listings.labels && ARRAY[?]::varchar[]", labels) if labels.any?
      scope = scope.where("listings.tags && ARRAY[?]::varchar[]", tags) if tags.any?
      scope = scope.where(region_id: region_ids) if region_ids.any?
      if shipping.include?("ship") && shipping.include?("pickup")
        scope = scope.where("listings.shipping_available = TRUE OR listings.local_pickup = TRUE")
      elsif shipping.include?("ship")
        scope = scope.where(shipping_available: true)
      elsif shipping.include?("pickup")
        scope = scope.where(local_pickup: true)
      end
      scope = scope.where(free_shipping: true) if free_shipping?
      scope = scope.on_sale if on_sale?
      scope = scope.where(store_id: Store.where(slug: seller).select(:id)) if seller.present?
    end

    scope
  end

  # Containment queries (`specs @> '{"key":"value"}'`) use the GIN index on
  # listings.specs. Values are OR-ed inside a key and AND-ed across keys.
  def apply_spec_filters(scope)
    spec_filters.each do |key, values|
      clauses = values.map { "listings.specs @> ?::jsonb" }
      payloads = values.map { |value| { key => value }.to_json }
      scope = scope.where(clauses.join(" OR "), *payloads)
    end
    scope
  end

  def apply_price_range(scope)
    scope = scope.where("listings.price_cents >= ?", min_price_cents) if min_price_cents
    scope = scope.where("listings.price_cents <= ?", max_price_cents) if max_price_cents
    scope
  end

  def apply_sort(scope)
    case sort
    when "price_asc"
      scope.reorder(price_cents: :asc, published_at: :desc)
    when "price_desc"
      scope.reorder(price_cents: :desc, published_at: :desc)
    when "popular"
      scope.reorder(favorites_count: :desc, views_count: :desc, published_at: :desc)
    when "best_match"
      query.present? ? scope : scope.reorder(published_at: :desc, created_at: :desc)
    else
      scope.reorder(published_at: :desc, created_at: :desc)
    end
  end

  def cents_from_euros(value)
    return nil if value.blank?

    raw = value.to_s.strip.gsub(/[^\d.,-]/, "")
    return nil if raw.blank?

    raw = if raw.include?(",") && raw.include?(".")
      raw.delete(".").tr(",", ".")
    elsif raw.include?(",")
      parts = raw.split(",")
      parts.last.length == 3 ? raw.delete(",") : raw.tr(",", ".")
    else
      parts = raw.split(".")
      parts.last.length == 3 ? raw.delete(".") : raw
    end

    amount = BigDecimal(raw)
    return nil if amount.negative?

    (amount * 100).round
  rescue ArgumentError, TypeError
    nil
  end

  def truthy?(value)
    ActiveModel::Type::Boolean.new.cast(value) == true
  end

  def compute_facets
    keys = filter_keys
    return {} if keys.empty?

    rows = build_relation(include_specs: false, include_condition: true,
                          include_secondary: false, facets_only: true)
           .except(:order)
           .joins("CROSS JOIN LATERAL jsonb_each_text(listings.specs) AS spec_filter(key, value)")
           .where("spec_filter.key IN (?)", keys)
           .group("spec_filter.key", "spec_filter.value")
           .count

    rows.each_with_object({}) do |((key, value), count), result|
      (result[key] ||= {})[value] = count
    end
  end

  def build_active_filters
    filters = []
    filters << chip("q", query, I18n.t("search.chips.query", query: query), remove_params("q")) if query.present?

    if min_price_cents || max_price_cents
      label = if min_price_cents && max_price_cents
        I18n.t("search.chips.price_range", min: money(min_price_cents), max: money(max_price_cents))
      elsif min_price_cents
        I18n.t("search.chips.price_min", min: money(min_price_cents))
      else
        I18n.t("search.chips.price_max", max: money(max_price_cents))
      end
      filters << chip("price", [ min_price_cents, max_price_cents ], label,
                      remove_params("min_price", "max_price"))
    end

    conditions.each do |condition|
      filters << chip("condition", condition,
                      I18n.t("listings.conditions.#{condition}"),
                      remove_array_value("condition", condition))
    end

    labels.each do |label|
      filters << chip("labels", label, I18n.t("listings.labels.#{label}"),
                      remove_array_value("labels", label))
    end

    tags.each do |tag|
      filters << chip("tags", tag, I18n.t("listings.tags.#{tag}"),
                      remove_array_value("tags", tag))
    end

    spec_filters.each do |key, values|
      definition = filter_definitions.find { |item| item.key == key }
      next if definition.nil?

      values.each do |value|
        option = definition.filter_options.find { |item| item.value == value }
        filters << chip("spec_#{key}", value, "#{definition.name}: #{option&.label || value}",
                        remove_spec_value(key, value))
      end
    end

    region_names = Region.where(id: region_ids).index_by(&:id)
    region_ids.each do |id|
      region = region_names[id]
      filters << chip("region", id, region&.name || id.to_s, remove_array_value("region_id", id))
    end

    shipping.each do |mode|
      filters << chip("shipping", mode, I18n.t("search.chips.#{mode}"),
                      remove_array_value("shipping", mode))
    end

    if free_shipping?
      filters << chip("free_shipping", true, I18n.t("listings.labels.free_shipping"),
                      remove_params("free_shipping"))
    end

    if on_sale?
      filters << chip("on_sale", true, I18n.t("search.chips.on_sale"), remove_params("on_sale"))
    end

    filters
  end

  def chip(key, value, label, remove_params_hash)
    SearchFilter.new(key, value, label, remove_params_hash)
  end

  def money(cents)
    ActionController::Base.helpers.number_to_currency(cents.to_i / 100.0, unit: "€", precision: 0)
  end

  def base_params
    @base_params ||= begin
      permitted = @params.to_h.slice(
        "q", "min_price", "max_price", "condition", "labels", "tags", "f", "region_id",
        "shipping", "free_shipping", "on_sale", "deals", "seller", "sort", "category_id",
        "include_sold"
      )
      permitted.each_with_object({}) do |(key, value), result|
        next if value.blank?

        result[key] = value
      end
    end
  end

  def remove_params(*keys)
    base_params.except(*keys)
  end

  def remove_array_value(key, value)
    copy = base_params.deep_dup
    values = Array(copy[key]).reject { |item| item.to_s == value.to_s }
    if values.any?
      copy[key] = values
    else
      copy.delete(key)
    end
    copy
  end

  def remove_spec_value(key, value)
    copy = base_params.deep_dup
    specs = copy["f"].respond_to?(:to_h) ? copy["f"].to_h.deep_dup : {}
    values = Array(specs[key]).reject { |item| item.to_s == value.to_s }
    if values.any?
      specs[key] = values
    else
      specs.delete(key)
    end
    if specs.any?
      copy["f"] = specs
    else
      copy.delete("f")
    end
    copy
  end

  def total_cache_key
    [ "listing_search", "count", "v1", I18n.locale, self.class.cache_version, category&.id, digest ]
  end

  def facets_cache_key
    facet_digest = Digest::SHA256.hexdigest([
      category&.id, query, min_price_cents, max_price_cents, conditions.sort, filter_keys.sort
    ].to_s)
    [ "listing_search", "facets", "v1", I18n.locale, self.class.cache_version, facet_digest ]
  end

  class Result
    attr_reader :search, :pagy, :listings

    def initialize(search)
      @search = search
      count = search.total_count
      pages = [ (count.to_f / PER_PAGE).ceil, MAX_PAGE ].min
      pages = 1 if pages < 1
      @pagy = Pagy.new(count: count, page: [ search.page, pages ].min, limit: PER_PAGE)
      @listings = search.relation.offset(@pagy.offset).limit(@pagy.limit).to_a
    end

    delegate :relation, :total_count, :active_filters, :facets, :condition_counts, :category,
             :normalized_params, :digest, :query, :sort, :page, :conditions, :labels,
             :tags, :spec_filters, :region_ids, :shipping, :free_shipping?, :on_sale?,
             :seller, :min_price_cents, :max_price_cents, :filter_definitions,
             to: :search

    def empty?
      total_count.zero?
    end

    def selected_specs(key)
      Array(spec_filters[key])
    end

    def supported_condition_counts
      Listing.conditions.keys.index_with { |condition| condition_counts[condition] || 0 }
    end
  end
end
