# All data for the seller dashboard (/seller/dashboard). Every panel is one
# small aggregate query (no N+1s) memoized per instance, so the view can ask
# for anything in any order.
#
# Revenue is provisional until Phase 5: it sums the price_cents of listings
# that went sold within the period (sold_at), not real order totals — orders
# become the source of truth then.
module Seller
  class Dashboard
    PERIODS = { "7d" => 7, "30d" => 30, "90d" => 90 }.freeze
    DEFAULT_PERIOD = "30d"

    # A draft untouched for this many days needs the seller's attention.
    STALE_DRAFT_DAYS = 7
    ATTENTION_LIMIT = 5
    TOP_LISTINGS_LIMIT = 5
    ACTIVITY_LIMIT = 10

    # Statuses where a missing photo is a problem (sold/archived are done).
    PHOTO_STATUSES = %w[draft pending_review rejected published paused].freeze

    attr_reader :store, :period

    # `period` is the raw param; anything outside PERIODS falls back to the
    # default so the view never renders a dead switcher tab.
    def initialize(store, period: nil)
      @store = store
      @period = period.presence_in(PERIODS.keys) || DEFAULT_PERIOD
    end

    def period_days
      PERIODS.fetch(period)
    end

    def period_start
      @period_start ||= period_days.days.ago
    end

    # --- KPI cards ------------------------------------------------------------

    # One grouped query behind every status-based card (Listing.status_counts).
    def status_counts
      @status_counts ||= Listing.status_counts(store)
    end

    def active_listings_count
      status_counts.fetch("published")
    end

    def pending_review_count
      status_counts.fetch("pending_review")
    end

    # Lifetime counter sums — one simple SUM each, no per-row loading.
    def total_views
      @total_views ||= store.listings.sum(:views_count)
    end

    def favorites_count
      @favorites_count ||= store.listings.sum(:favorites_count)
    end

    # Denormalized store counters (follow counter cache + rating recalculator).
    def followers_count
      store.followers_count
    end

    def rating_avg
      store.rating_avg.to_f
    end

    def rating_count
      store.ratings_count
    end

    def sold_in_period
      store.listings.sold.where(sold_at: period_start..)
    end

    def sold_count
      @sold_count ||= sold_in_period.count
    end

    # TODO Phase 5: switch to order totals once orders exist — until then
    # this is the sum of the sold listings' prices (single SUM).
    def revenue_cents
      @revenue_cents ||= sold_in_period.sum(:price_cents)
    end

    # --- Sold-per-day sparkline -----------------------------------------------

    # [Date, count] pairs for every day in the period, zero-filled, oldest
    # first — the view turns them into pure-CSS bars.
    def sold_per_day
      @sold_per_day ||= begin
        counts = sold_in_period.group(Arel.sql("listings.sold_at::date")).count
        (period_start.to_date..Time.current.to_date).map { |day| [ day, counts.fetch(day, 0) ] }
      end
    end

    def sold_per_day_max
      sold_per_day.map(&:last).max
    end

    # --- Needs attention ---------------------------------------------------------

    def rejected_listings
      @rejected_listings ||= attention_scope.where(status: "rejected").to_a
    end

    # Drafts the seller has not touched in a week.
    def stale_drafts
      @stale_drafts ||= attention_scope.where(status: "draft")
                                       .where(updated_at: ...STALE_DRAFT_DAYS.days.ago).to_a
    end

    # Live-ish listings with an empty gallery (submitting for review already
    # requires a photo, so this mostly catches post-approval removals).
    def listings_without_photos
      @listings_without_photos ||= attention_scope
                                   .where(status: PHOTO_STATUSES)
                                   .where.missing(:images_attachments).to_a
    end

    def needs_attention?
      (rejected_listings + stale_drafts + listings_without_photos).any?
    end

    # --- Tables -------------------------------------------------------------------

    def top_listings
      @top_listings ||= store.listings
                             .order(views_count: :desc, id: :desc)
                             .limit(TOP_LISTINGS_LIMIT).to_a
    end

    # Latest status changes: any lifecycle event bumps updated_at, so the
    # 10 most recently touched listings are the activity feed.
    def recent_activity
      @recent_activity ||= store.listings
                                .order(updated_at: :desc, id: :desc)
                                .limit(ACTIVITY_LIMIT).to_a
    end

    # --- Onboarding (new-seller empty state) ----------------------------------------

    def onboarding?
      @onboarding ||= !store.listings.exists?
    end

    # Checklist rows: { key:, done: } — the view translates `key` and links
    # unfinished items to the right page.
    def onboarding_checklist
      @onboarding_checklist ||= [
        { key: "logo", done: store.logo.attached? },
        { key: "bio", done: store.bio.present? },
        { key: "first_listing", done: store.listings.exists? },
        { key: "first_approved", done: store.listings.where.not(published_at: nil).exists? }
      ]
    end

    private

    # Shared base for the attention lists: newest activity first, capped.
    def attention_scope
      store.listings.order(updated_at: :desc, id: :desc).limit(ATTENTION_LIMIT)
    end
  end
end
