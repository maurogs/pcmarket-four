module PcFinder
  # Scores visible gaming PCs and workstations against a quiz answer set.
  # SQL preselects at most 500 candidates; scoring stays in pure Ruby so the
  # engine can combine listing FPS data, GPU tier fallbacks and value.
  class Recommender
    RESOLUTIONS = {
      "1080p" => { multiplier: 1.0, label: "1080p" },
      "1440p" => { multiplier: 0.75, label: "1440p" },
      "4k" => { multiplier: 0.5, label: "4K" }
    }.freeze

    FPS_TARGETS = [ 60, 144, 240 ].freeze

    BUDGETS = {
      "under_800" => { min: nil, max: 80_000 },
      "800_1200" => { min: 80_000, max: 120_000 },
      "1200_2000" => { min: 120_000, max: 200_000 },
      "2000_plus" => { min: 200_000, max: nil }
    }.freeze

    CATEGORY_SLUGS = %w[gaming-pcs workstations].freeze

    GPU_TIERS = [
      [ "RTX 5090", 100 ], [ "RTX 5080", 94 ], [ "RTX 5070 Ti", 88 ],
      [ "RTX 5070", 82 ], [ "RTX 5060 Ti", 72 ], [ "RTX 5060", 64 ],
      [ "RTX 4090", 96 ], [ "RTX 4080", 90 ], [ "RTX 4070 Ti", 84 ],
      [ "RTX 4070", 76 ], [ "RTX 4060 Ti", 66 ], [ "RTX 4060", 58 ],
      [ "RTX 3090", 88 ], [ "RTX 3080", 80 ], [ "RTX 3070", 70 ],
      [ "RTX 3060", 52 ],
      [ "RX 9070 XT", 88 ], [ "RX 9070", 84 ], [ "RX 7900 XTX", 90 ],
      [ "RX 7900 XT", 86 ], [ "RX 7800 XT", 78 ], [ "RX 7700 XT", 72 ],
      [ "RX 7600", 60 ],
      [ "RX 6800 XT", 74 ], [ "RX 6700 XT", 64 ], [ "RX 6600", 35 ],
      [ "Arc B580", 58 ], [ "Arc A770", 55 ]
    ].freeze

    DEFAULT_GPU_TIER = 40
    ESPORTS_SLUGS = %w[valorant league-of-legends counter-strike-2 fortnite].freeze
    AAA_SLUGS = %w[cyberpunk-2077 monster-hunter-wilds].freeze

    Result = Struct.new(
      :listing_id, :score, :performance, :value, :fit, :estimated_fps,
      keyword_init: true
    )

    attr_reader :games, :resolution, :fps_target, :budget, :case_colour,
                :cooling, :vibes, :sort

    def initialize(games: [], resolution: "1080p", fps: 60, budget: nil,
                   case_colour: "any", cooling: "any", vibes: [], sort: "best")
      @games = Array(games).map(&:to_s).select { |slug| slug.match?(/\A[a-z0-9-]+\z/) }.first(3)
      @resolution = RESOLUTIONS.key?(resolution.to_s) ? resolution.to_s : "1080p"
      @fps_target = normalize_fps(fps)
      @budget = BUDGETS.key?(budget.to_s) ? budget.to_s : nil
      @case_colour = case_colour.to_s.presence || "any"
      @cooling = cooling.to_s.presence || "any"
      @vibes = Array(vibes).map(&:to_s) & Listing::TAGS
      @sort = %w[best price_asc price_desc].include?(sort.to_s) ? sort.to_s : "best"
    end

    def results
      scores = Rails.cache.fetch(cache_key, expires_in: 10.minutes) { score_candidates }
      listings = Listing.where(id: scores.map { |score| score[:listing_id] })
                        .includes(:store, :category, images_attachments: :blob)
                        .index_by(&:id)

      scores.filter_map do |score|
        listing = listings[score[:listing_id]]
        next unless listing

        Result.new(**score.merge(listing_id: listing.id))
      end
    end

    def budget_cents
      BUDGETS[budget]
    end

    def target_label
      fps_target >= 240 ? "240+" : fps_target.to_s
    end

    def self.estimate_fps(gpu_model:, resolution:, game_slug:)
      tier = gpu_tier(gpu_model)
      base = tier * 2.4
      base * RESOLUTIONS.fetch(resolution.to_s, RESOLUTIONS["1080p"])[:multiplier] * game_weight(game_slug)
    end

    def self.gpu_tier(gpu_model)
      text = gpu_model.to_s.upcase
      match = GPU_TIERS.find { |pattern, _tier| text.include?(pattern.upcase) }
      match ? match.last : DEFAULT_GPU_TIER
    end

    def self.game_weight(game_slug)
      slug = game_slug.to_s
      return 1.6 if ESPORTS_SLUGS.include?(slug)
      return 0.8 if AAA_SLUGS.include?(slug)

      1.0
    end

    private

    def normalize_fps(value)
      number = value.to_i
      return 240 if number >= 240
      return 144 if number >= 144
      return 60 if number > 0

      60
    end

    def cache_key
      digest = [ games.sort, resolution, fps_target, budget, case_colour, cooling, vibes.sort ]
      "pc_finder/v1/#{Digest::SHA256.hexdigest(digest.to_json)}/#{Listing.maximum(:updated_at).to_i}"
    end

    def candidates
      @candidates ||= begin
        category_ids = Category.where(slug: CATEGORY_SLUGS).to_a.flat_map(&:subtree_ids)
        scope = Listing.visible.where(category_id: category_ids)
        if budget_cents
          scope = scope.where("listings.price_cents >= ?", budget_cents[:min]) if budget_cents[:min]
          scope = scope.where("listings.price_cents <= ?", budget_cents[:max]) if budget_cents[:max]
        end
        scope.order(Arel.sql("listings.performance_score DESC NULLS LAST")).limit(500).to_a
      end
    end

    def score_candidates
      candidates = candidates_matching_preferences
      raw = candidates.map do |listing|
        performance = performance_score(listing)
        {
          listing_id: listing.id,
          performance: performance,
          estimated_fps: estimated_fps(listing),
          per_euro: performance / [ listing.price_cents.to_i / 1000.0, 1.0 ].max
        }
      end
      return [] if raw.empty?

      per_euro_values = raw.map { |row| row[:per_euro] }
      min = per_euro_values.min
      max = per_euro_values.max

      raw.map do |row|
        value = if max == min
          50.0
        else
          100.0 * (row[:per_euro] - min) / (max - min)
        end
        score = 0.7 * row[:performance] + 0.3 * value
        {
          listing_id: row[:listing_id],
          performance: row[:performance].round(1),
          value: value.round(1),
          score: score.round(1),
          fit: fit_for(row[:performance]),
          estimated_fps: row[:estimated_fps]
        }
      end
    end

    def candidates_matching_preferences
      rows = candidates.select { |listing| matches_colour?(listing) && matches_cooling?(listing) }
      return rows if vibes.empty?

      rows.select { |listing| (Array(listing.tags).map(&:to_s) & vibes).any? }
    end

    def matches_colour?(listing)
      colour = case_colour.downcase
      return true if colour == "any"

      listing.specs.to_h["colour"].to_s.downcase == colour
    end

    def matches_cooling?(listing)
      return true if cooling == "any"

      value = listing.specs.to_h["cpu_cooler_type"].to_s.downcase
      return true if cooling == "aio" && %w[aio custom\ loop].include?(value)
      return true if cooling == "air" && value == "air"

      false
    end

    def performance_score(listing)
      return no_game_performance(listing) if games.empty?

      scores = games.map { |slug| game_fit(listing, slug) }
      scores.sum / scores.size
    end

    def no_game_performance(listing)
      tier = self.class.gpu_tier(gpu_model(listing))
      (tier * RESOLUTIONS.fetch(resolution)[:multiplier]).clamp(0, 100)
    end

    def game_fit(listing, game_slug)
      fps = fps_for(listing, game_slug)
      return 0 if fps.nil?
      return 100 if fps >= fps_target

      (fps / fps_target.to_f * 100).clamp(0, 100)
    end

    def fps_for(listing, game_slug)
      explicit = listing.game_fps.to_h.dig(game_slug, resolution)
      return explicit.to_f if explicit.present?

      self.class.estimate_fps(gpu_model: gpu_model(listing), resolution: resolution,
                              game_slug: game_slug)
    end

    def estimated_fps(listing)
      if games.empty?
        fps = (self.class.gpu_tier(gpu_model(listing)) * 2.4 *
               RESOLUTIONS.fetch(resolution)[:multiplier]).round
        return { "overall" => fps }
      end

      games.index_with { |slug| fps_for(listing, slug).round }
    end

    def gpu_model(listing)
      listing.specs.to_h["gpu_model"].presence || listing.model_name_text.presence ||
        listing.brand.to_s
    end

    def fit_for(performance)
      return "great" if performance >= 90
      return "good" if performance >= 70

      "stretch"
    end
  end
end
