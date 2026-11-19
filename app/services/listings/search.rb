module Listings
  # Browse/search query object: one place that turns search-params into a
  # paginated, filtered, sorted listing page plus sidebar facet counts.
  #
  # Params: :q, :category (slug), :store (slug), :specs ({"key" => ["value", …]}),
  # :min_price / :max_price (cents), :condition (enum names), :labels,
  # :seller_tags, :sort, :page, :per_page. :include_sold keeps a store's sold
  # listings in the results (sorted after the active ones) for storefronts.
  class Search
    SORTS = %w[relevance best_match newest price_asc price_desc most_watched].freeze
    DEFAULT_PER_PAGE = 24
    MAX_PER_PAGE = 60
    CACHE_TTL = 5.minutes

    # Sidebar groups rendered from these (own + inherited definitions).
    DIMENSION_FACETS = %w[condition labels seller_tags].freeze

    Result = Struct.new(
      :listings, :pagy, :facets, :dimension_facets, :filter_definitions,
      :selected_filter_options, :category, keyword_init: true
    )

    def self.call(params)
      new(params).call
    end

    def initialize(params)
      @params = normalize(params)
    end

    def call
      Result.new(
        listings: records, pagy: pagy, facets: facet_data,
        dimension_facets: dimension_facet_data, filter_definitions: sidebar_definitions,
        selected_filter_options: selected_filter_options, category: category
      )
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

    def store
      return @store if defined?(@store)

      @store = params["store"].presence && Store.find_by_param(params["store"])
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
    # `exclude` skips one facet dimension (a spec key or a DIMENSION_FACETS
    # name) so counts include the options that are currently selected.
    def base_scope(exclude: nil, include_sold: sold_last?)
      scope = if store
        scope = Listing.for_store(store).where(status: include_sold ? %w[published sold] : %w[published])
      else
        Listing.visible
      end
      scope = scope.in_category(category) if category
      scope = scope.matching(query) if query
      remaining = spec_filters.except(exclude.to_s)
      scope = scope.with_specs(remaining) if remaining.any?
      scope = scope.price_between(params["min_price"], params["max_price"])
      unless exclude == "condition"
        conditions = list_param("condition") & Listing.conditions.keys
        scope = scope.condition_in(conditions) if conditions.any?
      end
      unless exclude == "labels"
        labels = list_param("labels")
        scope = scope.with_labels(labels) if labels.any?
      end
      unless exclude == "seller_tags"
        tags = list_param("seller_tags")
        scope = scope.with_seller_tags(tags) if tags.any?
      end
      scope
    end

    # Sold listings (storefronts via :include_sold) sort after the active ones.
    def sold_last?
      store.present? && params["include_sold"].present?
    end

    def sold_last_sql
      "CASE WHEN listings.status = 'sold' THEN 1 ELSE 0 END"
    end

    def sorted_scope(scope)
      orders = [ sold_last_sql ] if sold_last?
      orders = orders || []
      orders <<
        case sort
        when "price_asc" then "listings.price_cents ASC, listings.id ASC"
        when "price_desc" then "listings.price_cents DESC, listings.id ASC"
        when "newest" then "listings.published_at DESC NULLS LAST, listings.id DESC"
        when "most_watched" then "listings.watchers_count DESC, listings.published_at DESC NULLS LAST, listings.id DESC"
        else best_match_order
        end
      scope.reorder(Arel.sql(orders.join(", ")))
    end

    def best_match_order
      [
        "CASE WHEN listings.featured_until > NOW() THEN 0 ELSE 1 END",
        "COALESCE(listings.published_at, listings.created_at) DESC",
        "listings.id DESC"
      ].join(", ")
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
      scope = if query && sort == "relevance"
        rank = "ts_rank(listings.searchable, websearch_to_tsquery('listings_unaccented', " \
               "#{Listing.connection.quote(query)})) DESC, listings.id DESC"
        orders = sold_last? ? [ sold_last_sql, rank ] : [ rank ]
        scope.reorder(Arel.sql(orders.join(", ")))
      else
        sorted_scope(scope)
      end
      scope.with_includes.offset(pagy.offset).limit(pagy.limit)
    end

    # --- Facets ----------------------------------------------------------

    def sidebar_definitions
      @sidebar_definitions ||= category ? category.effective_filter_definitions.select { |d| d.show_in_sidebar && d.selection_like? } : []
    end

    # { "filter_key" => { "option_value" => published_count } } plus the
    # fixed dimensions (condition/labels/seller_tags), cached for CACHE_TTL
    # and keyed on params + data version so edits invalidate early.
    def facet_data
      Rails.cache.fetch(facets_cache_key, expires_in: CACHE_TTL) do
        sidebar_definitions.to_h { |definition| [ definition.key, facet_counts(definition) ] }
      end
    end

    # Raw machine values only — display labels/translations resolve at render
    # time, so the cache works for every locale.
    def dimension_facet_data
      Rails.cache.fetch("#{facets_cache_key}/dimensions", expires_in: CACHE_TTL) do
        {
          "condition" => condition_counts,
          "labels" => slug_counts("labels"),
          "seller_tags" => slug_counts("seller_tags")
        }
      end
    end

    # { "gpu_chipset" => { "nvidia" => "NVIDIA" } } — labels of the values
    # currently selected in specs, for the active-filter pills.
    def selected_filter_options
      @selected_filter_options ||= spec_filters.to_h do |key, values|
        options = FilterOption.joins(:filter_definition)
                              .where(filter_definitions: { key: key }, value: values)
                              .ordered
        [ key, options.to_h { |option| [ option.value, option.label ] } ]
      end
    end

    # One grouped query per definition: every active option of the definition
    # LEFT JOINed against the search results *without that filter applied*,
    # counting jsonb array containment per option value.
    def facet_counts(definition)
      results = base_scope(exclude: definition.key, include_sold: false).select("listings.id, listings.specs").to_sql
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

    # { "new_sealed" => 3, … } with the enum keys (column stores integers).
    def condition_counts
      base_scope(exclude: "condition", include_sold: false).group(:condition).count(:id)
        .transform_keys { |value| Listing.conditions.key(value.to_i) }
    end

    # { slug => count } for product labels / seller tags.
    def slug_counts(dimension)
      table = dimension == "labels" ? "product_labels" : "seller_tags"
      base_scope(exclude: dimension, include_sold: false)
        .joins(dimension == "labels" ? :product_labels : :seller_tags)
        .group("#{table}.slug").count(:id)
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
