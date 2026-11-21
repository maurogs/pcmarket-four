class TrustStats
  CACHE_KEY = "trust_stats/v1".freeze
  CACHE_TTL = 1.hour

  MINIMUMS = {
    completed_orders: 10,
    verified_stores: 3,
    average_rating: 3,
    reviewed_listings: 25
  }.freeze

  def self.call
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { new.call }
  end

  def call
    reviewed_stores = Store.where("reviews_count > 0").count
    rating = Store.where("reviews_count > 0").average(:rating_avg)&.to_f

    {
      completed_orders: stat(Order.where(status: Order.statuses[:completed]).count,
                             minimum: MINIMUMS[:completed_orders]),
      verified_stores: stat(Store.where(verified: true).count,
                            minimum: MINIMUMS[:verified_stores]),
      average_rating: stat(rating, minimum: MINIMUMS[:average_rating],
                                   count: reviewed_stores),
      reviewed_listings: stat(Listing.where.not(reviewed_at: nil).count,
                              minimum: MINIMUMS[:reviewed_listings])
    }
  end

  private

  def stat(value, minimum:, count: nil)
    sufficient = count ? count >= minimum : value.to_i >= minimum
    { value: value, sufficient: sufficient }
  end
end
