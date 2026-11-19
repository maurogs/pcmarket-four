module Listings
  # Browse/search query object: one place that turns search-params into a
  # paginated, filtered, sorted listing page plus sidebar facet counts.
  #
  # Params: :q, :category (slug), :specs ({"key" => ["value", …]}), :min_price /
  # :max_price (cents), :condition (enum names), :labels, :seller_tags, :sort,
  # :page, :per_page.
  class Search
    SORTS = %w[relevance best_match newest price_asc price_desc most_watched].freeze
    DEFAULT_PER_PAGE = 24
    MAX_PER_PAGE = 60
    CACHE_TTL = 5.minutes

    Result = Struct.new(:listings, :pagy, :facets, :category, keyword_init: true)

    def self.call(params)
      new(params).call
    end

    def initialize(params)
      @params = normalize(params)
    end

    def call
      Result.new(listings: records, pagy: pagy, facets: facet_data, category: category)
    end

    private

    attr_reader :params

    def normalize(raw)
      raw = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
      raw.transform_keys(&:to_s)
    end

    # --- Scope assembly --------------------------------------------------

    def category
      return @category if defined?(@category)

      @category = params["category"].presence && Category.find_by_param(params["category"])
    end

    def query
      params["q"].to_s.strip.presence
    end

    def sort
      value = params["sort"].to_s
      return value if SORTS.include?(value) && value != "relevance"
      return "relevance" if query

      "best_match"
    end

    def spec_filters
      (params["specs"].presence || {}).to_h.transform_keys(&:to_s)
        .transform_values { |values| Array(values).map(&:to_s).reject(&:blank?) }
        .reject { |_, values| values.empty? }
    end

    # Conditions etc. arrive as comma strings or arrays from query params.
    def list_param(key)
      Array(params[key]).flat_map { |v| v.is_a?(String) ? v.split(",") : Array(v) }
        .map(&:to_s).map(&:strip).reject(&:blank?)
    end

    # The fully filtered relation (before pagination/sorting). Text search
    # runs straight against the trigger-maintained `searchable` column, so
    # counts and facet subqueries wrap cleanly (no pg_search rank subselect).
    def base_scope(exclude_key: nil)
      scope = Listing.visible
      scope = scope.in_category(category) if category
      scope = scope.matching(query) if query
      remaining = spec_filters.except(exclude_key.to_s)
      scope = scope.with_specs(remaining) if remaining.any?
      scope = scope.price_between(params["min_price"], params["max_price"])
      conditions = list_param("condition") & Listing.conditions.keys
      scope = scope.condition_in(conditions) if conditions.any?
      labels = list_param("labels")
      scope = scope.with_labels(labels) if labels.any?
      tags = list_param("seller_tags")
      scope = scope.with_seller_tags(tags) if tags.any?
      scope
    end

    def sorted_scope(scope)
      case sort
      when "price_asc" then scope.reorder(price_cents: :asc, id: :asc)
      when "price_desc" then scope.reorder(price_cents: :desc, id: :asc)
      when "newest" then scope.reorder(published_at: :desc, id: :desc)
      when "most_watched" then scope.reorder(watchers_count: :desc, published_at: :desc, id: :desc)
      else scope.reorder(best_match_order)
      end
    end

    def best_match_order
      Arel.sql(
        "CASE WHEN listings.featured_until > NOW() THEN 0 ELSE 1 END, " \
        "COALESCE(listings.published_at, listings.created_at) DESC, listings.id DESC"
      )
    end

    # --- Pagination ------------------------------------------------------

    def total_count
      @total_count ||= base_scope.except(:order).count(:id)
    end

    def pagy
      per_page = params["per_page"].present? ? params["per_page"].to_i.clamp(1, MAX_PER_PAGE) : DEFAULT_PER_PAGE
      @pagy ||= Pagy::Offset.new(
        count: total_count,
        page: [ params["page"].to_i, 1 ].max,
        limit: per_page
      )
    end

    def records
      scope = base_scope
      scope = query && sort == "relevance" ? scope.by_relevance(query) : sorted_scope(scope)
      scope.with_includes.offset(pagy.offset).limit(pagy.limit)
    end

    # --- Facets ----------------------------------------------------------

    def sidebar_definitions
      return [] unless category

      category.effective_filter_definitions.select { |d| d.show_in_sidebar && d.selection_like? }
    end

    # { "filter_key" => { "option_value" => published_count } }, cached for
    # CACHE_TTL and keyed on params + data version so edits invalidate early.
    def facet_data
      Rails.cache.fetch(facets_cache_key, expires_in: CACHE_TTL) do
        sidebar_definitions.to_h { |definition| [ definition.key, facet_counts(definition) ] }
      end
    end

    # One grouped query per definition: every active option of the definition
    # LEFT JOINed against the search results *without that filter applied*,
    # counting jsonb array containment per option value.
    def facet_counts(definition)
      results = base_scope(exclude_key: definition.key).select("listings.id, listings.specs").to_sql
      key = Listing.connection.quote(definition.key)
      sql = <<~SQL
        SELECT o.value, COUNT(s.id)
        FROM filter_options o
        LEFT JOIN (#{results}) s
          ON s.specs -> #{key} @> jsonb_build_array(o.value::text)
        WHERE o.filter_definition_id = #{definition.id} AND o.active
        GROUP BY o.value
      SQL
      Listing.connection.select_all(sql).rows.to_h do |value, count|
        [ value.to_s, count.to_i ]
      end
    end

    def facets_cache_key
      @facets_cache_key ||= begin
        version = Listing.where(status: "published").maximum(:updated_at) || Time.at(0)
        relevant = params.except("page", "per_page")
        digest = Digest::SHA256.hexdigest(relevant.to_json)
        "listings/search/#{digest}/#{version.to_f.round(2)}"
      end
    end
  end
end
