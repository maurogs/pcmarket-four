module PcFinder
  # Data for the quiz landing sections. Queries live here so the controller
  # stays a thin presenter.
  class Landing
    VIBES = %w[minimalist rgb white anime retro cozy glass noctua sakura].freeze

    def self.call
      new.call
    end

    def call
      {
        vibes: vibe_tiles,
        under_1000: under_thousand,
        games: game_tiles
      }
    end

    private

    def base_scope
      Listing.visible
             .where(category_id: Category.where(slug: Recommender::CATEGORY_SLUGS).to_a.flat_map(&:subtree_ids))
             .includes(:store, images_attachments: :blob)
    end

    def vibe_tiles
      VIBES.map do |tag|
        listing = base_scope.where("? = ANY(listings.tags)", tag)
                            .order(published_at: :desc)
                            .first
        { tag: tag, listing: listing }
      end.select { |tile| tile[:listing].present? }
    end

    def under_thousand
      base_scope.where("listings.price_cents < ?", 100_000)
                .order(price_cents: :asc)
                .limit(8)
    end

    def game_tiles
      Game.visible.limit(3).map do |game|
        listing = base_scope.where("jsonb_exists(listings.game_fps, ?)", game.slug)
                            .order(published_at: :desc)
                            .first || base_scope.order(published_at: :desc).first
        { game: game, listing: listing }
      end
    end
  end
end
