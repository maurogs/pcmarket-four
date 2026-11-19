module PcFinder
  # Value object: raw PC Finder form params in, safe normalized selections out.
  # Every invalid or missing value silently falls back to its default, so the
  # recommender only ever sees valid input.
  class Query
    RESOLUTIONS = %w[1080p 1440p 2160p].freeze
    DEFAULT_RESOLUTION = "1080p"

    FPS_OPTIONS = [ 60, 144, 240 ].freeze
    DEFAULT_FPS = 60

    MAX_GAMES = 3

    # Budget slug → [min, max] price_cents (nil = unbounded).
    BUDGETS = {
      "any" => [ nil, nil ],
      "under_800" => [ nil, 80_000 ],
      "800_1200" => [ 80_000, 120_000 ],
      "1200_2000" => [ 120_000, 200_000 ],
      "over_2000" => [ 200_000, nil ]
    }.freeze
    DEFAULT_BUDGET = "any"

    CASE_PREFS = %w[any white black compact].freeze
    DEFAULT_CASE_PREF = "any"

    COOLING_OPTIONS = %w[any air aio].freeze
    DEFAULT_COOLING = "any"

    SORTS = %w[best_match price_asc price_desc performance].freeze
    DEFAULT_SORT = "best_match"

    attr_reader :games, :resolution, :fps, :budget, :case_pref, :cooling, :vibe, :sort, :page

    def initialize(params = {})
      raw = normalize(params)
      @games = load_games(raw["games"])
      @resolution = fetch(raw["resolution"], RESOLUTIONS, DEFAULT_RESOLUTION)
      @fps = FPS_OPTIONS.include?(raw["fps"].to_i) ? raw["fps"].to_i : DEFAULT_FPS
      @budget = fetch(raw["budget"], BUDGETS.keys, DEFAULT_BUDGET)
      @case_pref = fetch(raw["case_pref"], CASE_PREFS, DEFAULT_CASE_PREF)
      @cooling = fetch(raw["cooling"], COOLING_OPTIONS, DEFAULT_COOLING)
      @vibe = load_vibe(raw["vibe"])
      @sort = fetch(raw["sort"], SORTS, DEFAULT_SORT)
      @page = [ raw["page"].to_i, 1 ].max
    end

    # True when at least one valid game was selected — without a game there is
    # nothing to recommend against.
    def present?
      games.any?
    end

    # [min, max] price_cents for the selected budget (nil = unbounded).
    def budget_price_range
      BUDGETS.fetch(budget)
    end

    def min_price_cents
      budget_price_range.first
    end

    def max_price_cents
      budget_price_range.last
    end

    # Normalized selections as a params-style hash for building URLs (blank
    # selections and page 1 are left out to keep links short).
    def to_params
      {
        "games" => games.map(&:slug),
        "resolution" => resolution,
        "fps" => fps,
        "budget" => budget,
        "case_pref" => case_pref,
        "cooling" => cooling,
        "vibe" => vibe,
        "sort" => sort,
        "page" => (page if page > 1)
      }.compact_blank
    end

    private

    def normalize(raw)
      raw = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
      raw.transform_keys(&:to_s)
    end

    def fetch(value, allowed, default)
      value = value.to_s
      allowed.include?(value) ? value : default
    end

    # Games arrive as an array or comma-separated string; keep the requested
    # order, drop unknown/inactive slugs and cap at MAX_GAMES valid picks.
    def load_games(value)
      slugs = list(value).uniq
      return [] if slugs.empty?

      found = Game.active.where(slug: slugs).index_by(&:slug)
      slugs.filter_map { |slug| found[slug] }.first(MAX_GAMES)
    end

    def load_vibe(value)
      slug = list(value).first
      return if slug.blank?

      SellerTag.active.where(slug: slug).exists? ? slug : nil
    end

    def list(value)
      Array(value).flat_map { |v| v.to_s.split(",") }.map(&:strip).reject(&:blank?)
    end
  end
end
