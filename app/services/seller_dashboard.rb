class SellerDashboard
  PERIOD = 30
  REVENUE_STATUSES = %i[paid shipped delivered completed].freeze
  RECENT_LIMIT = 5

  def initialize(store)
    @store = store
    @user = store.user
  end

  def call
    Rails.cache.fetch(cache_key, expires_in: 5.minutes) { build }
  end

  private

  attr_reader :store, :user

  def cache_key
    "seller_dashboard/v2/#{store.id}/#{store.updated_at.to_i}/#{user.updated_at.to_i}/#{Date.current}"
  end

  def build
    current_window = PERIOD.days.ago.beginning_of_day..Time.current
    previous_window = (PERIOD * 2).days.ago.beginning_of_day..PERIOD.days.ago.beginning_of_day

    published_status = Listing.statuses[:published]
    pending_status = Listing.statuses[:pending_review]
    rejected_status = Listing.statuses[:rejected]

    listing_summary = store_listings.pick(
      Arel.sql("COUNT(*) FILTER (WHERE status = #{published_status})"),
      Arel.sql("COUNT(*) FILTER (WHERE status = #{rejected_status})"),
      Arel.sql("COUNT(*) FILTER (WHERE status = #{pending_status})"),
      Arel.sql("COALESCE(SUM(views_count) FILTER (WHERE status = #{published_status}), 0)")
    )
    active_count, rejected_count, pending_count, total_views = listing_summary

    sales_total, revenue_total = seller_orders.pick(
      Arel.sql("COUNT(*)"), Arel.sql("COALESCE(SUM(total_cents - commission_cents), 0)")
    )

    favourites_current = store_favorites.where(created_at: current_window).count
    favourites_previous = store_favorites.where(created_at: previous_window).count
    listings_current = store_listings.where(published_at: current_window).count
    listings_previous = store_listings.where(published_at: previous_window).count
    pending_current = store_listings.where(status: :pending_review, created_at: current_window).count
    pending_previous = store_listings.where(status: :pending_review, created_at: previous_window).count
    sales_current = seller_orders.where(created_at: current_window)
    sales_previous = seller_orders.where(created_at: previous_window)
    revenue_current = sales_current.sum("total_cents - commission_cents")
    revenue_previous = sales_previous.sum("total_cents - commission_cents")
    sales_count_current = sales_current.count
    sales_count_previous = sales_previous.count

    {
      metrics: {
        views: metric(total_views),
        favourites: metric(store_favorites.count, delta(favourites_current, favourites_previous)),
        active_listings: metric(active_count, delta(listings_current, listings_previous)),
        pending_review: metric(pending_count, delta(pending_current, pending_previous)),
        sales: metric(sales_total, delta(sales_count_current, sales_count_previous)),
        revenue: metric(revenue_total, delta(revenue_current, revenue_previous)),
        rating: metric(store.rating_avg.to_f)
      },
      orders_per_day: orders_per_day,
      action_needed: {
        rejected_listings: rejected_count,
        orders_to_ship: seller_orders.where(status: :paid).count,
        unanswered_conversations: Conversation.where(seller_id: user.id)
                                              .where("seller_unread_count > 0").count,
        completeness: store.completeness,
        completeness_checks: store.completeness_checks
      },
      recent_listings: store_listings.includes(:category, images_attachments: :blob)
                                      .order(updated_at: :desc).limit(RECENT_LIMIT).to_a
    }
  end

  def metric(value, change = nil)
    { value: value, delta: change }
  end

  def delta(current, previous)
    return nil if previous.to_i.zero? && current.to_i.zero?

    previous.to_i.zero? ? 100 : (((current - previous) * 100.0) / previous).round
  end

  def store_listings
    @store_listings ||= store.listings
  end

  def store_favorites
    @store_favorites ||= Favorite.joins(:listing).where(listings: { store_id: store.id })
  end

  def seller_orders
    @seller_orders ||= Order.where(seller_id: user.id, status: REVENUE_STATUSES)
  end

  def orders_per_day
    counts = Order.where(seller_id: user.id)
                  .where(created_at: PERIOD.days.ago.beginning_of_day..Time.current)
                  .group(Arel.sql("DATE(created_at)")).count
    (PERIOD - 1).downto(0).each_with_object({}) do |days_ago, result|
      date = days_ago.days.ago.to_date
      result[date] = counts[date].to_i
    end
  end
end
