require "test_helper"

# Seller::Dashboard aggregates every dashboard panel from one small query
# each. Listings are created per test (no global listing fixtures); sold_at
# / updated_at are backdated with update_columns so period filtering is
# deterministic.
class Seller::DashboardTest < ActiveSupport::TestCase
  setup do
    @store = stores(:confirmed_store)
  end

  def dashboard(period: nil)
    Seller::Dashboard.new(@store, period: period)
  end

  # A listing that went sold `days_ago` at the given price.
  def sold_listing(title:, price_cents:, days_ago:)
    listing = publish(create_listing(title: title, price_cents: price_cents))
    listing.mark_sold!
    listing.update_columns(sold_at: days_ago.days.ago)
    listing
  end

  # --- Period -----------------------------------------------------------------

  test "period defaults to 30d and unknown values fall back to it" do
    assert_equal "30d", dashboard.period
    assert_equal "7d", dashboard(period: "7d").period
    assert_equal "90d", dashboard(period: "90d").period
    assert_equal "30d", dashboard(period: "bogus").period
    assert_equal 7, dashboard(period: "7d").period_days
    assert_equal 90, dashboard(period: "90d").period_days
  end

  # --- KPI cards ----------------------------------------------------------------

  test "KPI cards count listings per status and sum the lifetime counters" do
    publish(create_listing(title: "Published Graphics Card One", views_count: 40, favorites_count: 3))
    publish(create_listing(title: "Published Graphics Card Two", views_count: 60, favorites_count: 2))
    pending = create_listing(title: "Pending Graphics Card")
    attach_photo(pending)
    pending.submit!
    create_listing(title: "Draft Graphics Card", views_count: 5)

    subject = dashboard
    assert_equal 2, subject.active_listings_count
    assert_equal 1, subject.pending_review_count
    assert_equal 105, subject.total_views
    assert_equal 5, subject.favorites_count
  end

  test "followers and rating cards read the denormalized store counters" do
    Follow.create!(follower: users(:pending), store: @store)
    @store.update_columns(rating_avg: 4.5, ratings_count: 2)

    subject = dashboard
    assert_equal 1, subject.followers_count
    assert_in_delta 4.5, subject.rating_avg
    assert_equal 2, subject.rating_count
  end

  test "sold count and revenue only cover the selected period" do
    sold_listing(title: "Old Sold Graphics Card", price_cents: 10_000, days_ago: 10)
    sold_listing(title: "Fresh Sold Graphics Card", price_cents: 20_000, days_ago: 1)

    assert_equal 2, dashboard.sold_count
    assert_equal 30_000, dashboard.revenue_cents

    week = dashboard(period: "7d")
    assert_equal 1, week.sold_count
    assert_equal 20_000, week.revenue_cents
  end

  # --- Sold-per-day sparkline -----------------------------------------------------

  test "sold_per_day returns a zero-filled day series for the period" do
    sold_listing(title: "Sparkline Sold Graphics Card", price_cents: 5_000, days_ago: 2)

    series = dashboard(period: "7d").sold_per_day
    assert_equal Date.current - 7, series.first.first
    assert_equal Date.current, series.last.first
    assert_equal 8, series.size
    assert_equal 1, series[-3].last # two days ago
    assert_equal 0, series.last.last
    assert_equal 1, dashboard(period: "7d").sold_per_day_max
  end

  test "sold_per_day ignores sales outside the period" do
    sold_listing(title: "Outside Window Sold Graphics Card", price_cents: 5_000, days_ago: 20)

    assert_equal 0, dashboard(period: "7d").sold_per_day_max
  end

  # --- Needs attention ---------------------------------------------------------------

  test "needs attention lists rejected, stale and photo-less listings" do
    rejected = create_listing(title: "Counterfeit Looking RAM")
    attach_photo(rejected)
    rejected.submit!
    rejected.reject!
    rejected.update!(rejection_reason: "Photos do not match the item.")

    stale = create_listing(title: "Ancient Draft Graphics Card")
    attach_photo(stale)
    stale.update_columns(updated_at: 8.days.ago)
    fresh = create_listing(title: "Recent Draft Graphics Card")
    attach_photo(fresh)

    photoless = publish(create_listing(title: "Photoless Live Graphics Card"))
    photoless.images.purge

    subject = dashboard
    assert_equal [ rejected.id ], subject.rejected_listings.map(&:id)
    assert_equal [ stale.id ], subject.stale_drafts.map(&:id)
    assert_equal [ photoless.id ], subject.listings_without_photos.map(&:id)
    assert_predicate subject, :needs_attention?
  end

  test "needs attention is false for a healthy store" do
    publish(create_listing(title: "Healthy Published Graphics Card"))

    assert_not dashboard.needs_attention?
  end

  # --- Tables ---------------------------------------------------------------------------

  test "top_listings orders by views and caps at five" do
    6.times { |i| create_listing(title: "Viewed Graphics Card #{i}", views_count: i * 10) }

    assert_equal [ 50, 40, 30, 20, 10 ], dashboard.top_listings.map(&:views_count)
  end

  test "recent_activity returns the ten most recently touched listings" do
    12.times do |i|
      create_listing(title: "Activity Graphics Card #{i}")
        .update_columns(updated_at: i.hours.ago)
    end

    activity = dashboard.recent_activity
    assert_equal 10, activity.size
    assert_equal "Activity Graphics Card 0", activity.first.title
  end

  # --- Onboarding -------------------------------------------------------------------------

  test "onboarding checklist tracks store setup progress" do
    checklist = dashboard.onboarding_checklist.index_by { |item| item[:key] }
    assert_predicate dashboard, :onboarding?
    assert_not checklist["logo"][:done]
    assert_not checklist["bio"][:done]
    assert_not checklist["first_listing"][:done]
    assert_not checklist["first_approved"][:done]

    @store.update!(bio: "Family-run PC shop since 2019.")
    listing = create_listing(title: "My First Graphics Card")
    checklist = dashboard.onboarding_checklist.index_by { |item| item[:key] }
    assert checklist["bio"][:done]
    assert checklist["first_listing"][:done]
    assert_not checklist["first_approved"][:done]
    assert_not_predicate dashboard, :onboarding?

    publish(listing)
    checklist = dashboard.onboarding_checklist.index_by { |item| item[:key] }
    assert checklist["first_approved"][:done]
  end

  test "onboarding checklist marks the logo step once a logo is attached" do
    @store.logo.attach(io: File.open(image_file), filename: "logo.png", content_type: "image/png")

    checklist = dashboard.onboarding_checklist.index_by { |item| item[:key] }
    assert checklist["logo"][:done]
  end

  # --- Memoization -------------------------------------------------------------------------

  test "panels are memoized per instance" do
    subject = dashboard
    assert_same subject.top_listings, subject.top_listings
    assert_same subject.recent_activity, subject.recent_activity
    assert_same subject.sold_per_day, subject.sold_per_day
    assert_same subject.status_counts, subject.status_counts
  end
end
