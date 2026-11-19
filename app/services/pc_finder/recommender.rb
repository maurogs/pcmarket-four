module PcFinder
  # Turns a PcFinder::Query into a paginated page of gaming PCs that can run
  # the selected games at the chosen resolution/fps. Hard filters (category,
  # performance, budget, cooling, compact case) narrow the relation; soft
  # preferences (vibe tag, case color) only boost the best_match ordering.
  class Recommender
    CATEGORY_SLUG = "gaming-pcs"
    PER_PAGE = 24
    MAX_ESTIMATED_FPS = 360

    # Spec option values (see db/seeds/08_filter_options.rb).
    COOLING_SPECS = { "air" => %w[air], "aio" => %w[aio-liquid] }.freeze
    COMPACT_CASE_SPECS = %w[mini-itx-sff micro-atx mini-tower].freeze
    CASE_COLOR_SPECS = %w[white black].freeze

    Result = Struct.new(
      :listings, :pagy, :required_score, :games, :resolution, :fps, keyword_init: true
    ) do
      # Rough frame rate the build would deliver for `game` at the query's
      # target, scaled by its performance headroom; nil without either score.
      def estimated_fps(listing, game)
        score = listing.performance_score
        required = game&.required_score(resolution, fps)
        return if score.nil? || required.nil? || required <= 0

        [ (fps * score.to_f / required).round, PcFinder::Recommender::MAX_ESTIMATED_FPS ].min
      end
    end

    def self.call(query)
      new(query).call
    end

    def initialize(query)
      @query = query.is_a?(Query) ? query : Query.new(query)
    end

    def call
      Result.new(
        listings: records, pagy: pagy, required_score: required_score,
        games: query.games, resolution: query.resolution, fps: query.fps
      )
    end

    private

    attr_reader :query

    # --- Selection -------------------------------------------------------

    def category
      return @category if defined?(@category)

      @category = Category.find_by_param(CATEGORY_SLUG)
    end

    # The hardest target across the selected games; nil when none of them
    # has a demand entry for the chosen resolution/fps.
    def required_score
      return @required_score if defined?(@required_score)

      @required_score = query.games.filter_map { |game| game.required_score(query.resolution, query.fps) }.max
    end

    # --- Scope assembly ----------------------------------------------------

    def base_scope
      return @base_scope if defined?(@base_scope)

      unless query.present? && category
        return @base_scope = Listing.none
      end

      scope = Listing.visible.in_category(category)
      scope = scope.where("listings.performance_score >= ?", required_score) if required_score
      scope = scope.price_between(query.min_price_cents, query.max_price_cents)
      cooling = COOLING_SPECS[query.cooling]
      scope = scope.with_specs("cpu_cooler_type" => cooling) if cooling
      if query.case_pref == "compact"
        scope = scope.with_specs("case_form_factor" => COMPACT_CASE_SPECS)
      end
      @base_scope = scope
    end

    # --- Sorting -----------------------------------------------------------

    def sorted_scope(scope)
      scope.reorder(Arel.sql(order_sql))
    end

    def order_sql
      case query.sort
      when "price_asc" then "listings.price_cents ASC, listings.id ASC"
      when "price_desc" then "listings.price_cents DESC, listings.id ASC"
      when "performance" then "listings.performance_score DESC NULLS LAST, listings.id DESC"
      else best_match_order
      end
    end

    # Soft-pref matches first, then performance headroom per euro.
    def best_match_order
      terms = []
      soft_matches = soft_matches_sql
      terms << "#{soft_matches} DESC" if soft_matches
      terms << headroom_sql
      terms << "listings.id DESC"
      terms.join(", ")
    end

    # One point per soft preference hit (vibe seller tag, case color); nil
    # when no soft preference is active.
    def soft_matches_sql
      terms = []
      if query.vibe
        terms << "CASE WHEN EXISTS (SELECT 1 FROM listing_seller_tags lst " \
                 "JOIN seller_tags st ON st.id = lst.seller_tag_id " \
                 "WHERE lst.listing_id = listings.id AND st.slug = #{quote(query.vibe)}) " \
                 "THEN 1 ELSE 0 END"
      end
      if CASE_COLOR_SPECS.include?(query.case_pref)
        json = quote({ "case_color" => [ query.case_pref ] }.to_json)
        terms << "CASE WHEN listings.specs @> #{json}::jsonb THEN 1 ELSE 0 END"
      end
      return if terms.empty?

      "(#{terms.join(" + ")})"
    end

    # (score - required) * 1000 / price_cents; free listings (price 0) sort
    # as if priced at one cent so the division stays safe.
    def headroom_sql
      required = (required_score || 0).to_i
      "((COALESCE(listings.performance_score, 0) - #{required}) * 1000.0 / " \
      "GREATEST(listings.price_cents, 1)) DESC"
    end

    def quote(value)
      Listing.connection.quote(value)
    end

    # --- Pagination --------------------------------------------------------

    def total_count
      @total_count ||= base_scope.count(:id)
    end

    def pagy
      @pagy ||= Pagy::Offset.new(count: total_count, page: query.page, limit: PER_PAGE)
    end

    def records
      sorted_scope(base_scope).with_includes.offset(pagy.offset).limit(pagy.limit)
    end
  end
end
