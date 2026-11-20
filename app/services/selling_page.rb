# Data for the "Sell on PCMarket" landing page: featured stores (sellers with
# sales, best first) and a recently-sold strip. Both are id lists cached on a
# data stamp (same pattern as HomePage) and reloaded with eager loads.
class SellingPage
  CACHE_TTL = 7.minutes
  FEATURED_STORES_LIMIT = 5
  SCROLLER_LIMIT = 14

  def featured_stores
    ids = load_cached("featured_stores") do
      Store.featured.limit(FEATURED_STORES_LIMIT).pluck(:id)
    end
    Store.where(id: ids).with_attached_logo.in_order_of(:id, ids)
  end

  def recently_sold
    ids = load_cached("recently_sold") do
      Listing.sold.where(sold_at: 1.month.ago..).order(sold_at: :desc, id: :desc)
              .limit(SCROLLER_LIMIT).pluck(:id)
    end
    Listing.where(id: ids).with_includes.in_order_of(:id, ids)
  end

  # Bumping this stamp invalidates the page's HTML fragments in the view.
  def data_version
    Rails.cache.fetch("selling/data_version", expires_in: 5.minutes) do
      [ Listing.maximum(:updated_at).to_f.round(2), Store.maximum(:updated_at).to_f.round(2) ]
    end
  end

  private

  def load_cached(key)
    ids = Rails.cache.fetch("selling/#{key}/#{data_version}/#{I18n.locale}", expires_in: CACHE_TTL) { yield }
    Array(ids).map(&:to_i)
  end
end
