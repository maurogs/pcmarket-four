# Data for the home page. Every section is a small id list cached for
# CACHE_TTL (keyed on the last data change) and reloaded with the card
# eager-loads, so a cache hit still renders without N+1 queries. The view
# fragment-caches the section HTML on the same data_version.
class HomePage
  CACHE_TTL = 7.minutes
  DEALS_LIMIT = 6
  SCROLLER_LIMIT = 14

  GPU_CATEGORY_SLUG = "gpus"
  THEME_TAG_SLUGS = %w[anime minimalist rgb].freeze

  def deals
    load_cached("deals") do
      Listing.visible.where("listings.original_price_cents > listings.price_cents")
              .order(discount_sql)
              .limit(DEALS_LIMIT).pluck(:id)
    end
  end

  def latest_gpus
    load_cached("latest_gpus") do
      gpus = Category.find_by(slug: GPU_CATEGORY_SLUG)
      gpus ? Listing.visible.in_category(gpus).newest.limit(SCROLLER_LIMIT).pluck(:id) : []
    end
  end

  def most_watched
    load_cached("most_watched") do
      Listing.visible.where(published_at: 1.week.ago..)
              .most_watched.limit(SCROLLER_LIMIT).pluck(:id)
    end
  end

  def on_sale
    load_cached("on_sale") do
      Listing.visible.where("listings.original_price_cents > listings.price_cents")
              .best_match.limit(SCROLLER_LIMIT).pluck(:id)
    end
  end

  def recently_sold
    load_cached("recently_sold") do
      Listing.sold.where(sold_at: 1.month.ago..).order(sold_at: :desc, id: :desc)
              .limit(SCROLLER_LIMIT).pluck(:id)
    end
  end

  # Curated build-aesthetic tags for the "Shop PCs by theme" tiles.
  def theme_tags
    load_cached("theme_tags") { SellerTag.active.where(slug: THEME_TAG_SLUGS).ordered.pluck(:slug) }
  end

  # Category the "Ready-to-ship PCs" tile links into (nil on partial catalog).
  def ready_to_ship_category
    @ready_to_ship_category ||= Category.active.find_by(slug: "gaming-pcs")
  end

  # Bumping this stamp invalidates the per-section HTML fragments in the view.
  def data_version
    Rails.cache.fetch("home/data_version", expires_in: 5.minutes) do
      Listing.maximum(:updated_at).to_f.round(2)
    end
  end

  # Relations in stored id order, with the card partial's associations.
  def listings(ids)
    Listing.where(id: ids).with_includes.in_order_of(:id, ids)
  end

  def theme_tag_records
    SellerTag.where(slug: theme_tags).ordered
  end

  private

  def discount_sql
    Arel.sql(
      "((listings.original_price_cents - listings.price_cents) " \
      "::numeric / listings.original_price_cents) DESC NULLS LAST"
    )
  end

  def load_cached(key)
    ids = Rails.cache.fetch("home/#{key}/#{data_version}/#{I18n.locale}", expires_in: CACHE_TTL) { yield }
    Array(ids).map(&:to_i)
  end
end
