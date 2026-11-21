module Admin
  # Aggregates the admin dashboard payload. The whole payload is cached for two
  # minutes so opening the panel stays cheap even on large datasets.
  class Dashboard
    CACHE_TTL = 2.minutes
    CACHE_KEY = "admin/dashboard/v2"
    PAID_STATUSES = %w[paid shipped delivered completed disputed].freeze
    WINDOW = 30
    TREND_WINDOW = 7

    attr_reader :now

    def initialize(now: Time.current)
      @now = now
    end

    def data
      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { build }
    end

    private

    def cache_key
      CACHE_KEY
    end

    def build
      {
        stats: stats,
        charts: charts,
        tables: tables,
        health: health
      }
    end

    def stats
      window_start = TREND_WINDOW.days.ago
      previous_start = (TREND_WINDOW * 2).days.ago
      current_totals = order_totals_since(window_start)
      previous_totals = order_totals_since(previous_start, window_start)
      newsletter_now, newsletter_previous = newsletter_counts(window_start, previous_start)
      newsletter_stats = trend(newsletter_now, newsletter_previous)
                          .merge(value: NewsletterSubscriber.confirmed.count)
      {
        new_users: trend(
          User.where("users.created_at >= ?", window_start).count,
          User.where(users: { created_at: previous_start...window_start }).count
        ),
        active_listings: trend(Listing.visible.count, nil),
        pending_review: trend(Listing.pending_review.count, nil, invert: true),
        published_today: trend(
          Listing.published.where("published_at >= ?", now.beginning_of_day).count,
          Listing.published.where(published_at: (now.beginning_of_day - 1.day)...now.beginning_of_day).count
        ),
        orders: trend(current_totals[2], previous_totals[2]),
        gmv_cents: trend(current_totals[0], previous_totals[0], money: true),
        commission_cents: trend(current_totals[1], previous_totals[1], money: true),
        open_disputes: trend(Order.disputed.count, nil, invert: true),
        open_reports: trend(Report.open.count, nil, invert: true),
        newsletter_subscribers: newsletter_stats
      }
    end

    def trend(value, previous, invert: false, money: false)
      change = if previous.to_i.positive?
        ((value.to_i - previous.to_i) * 100.0 / previous.to_i).round
      end
      {
        value: value.to_i,
        previous: previous&.to_i,
        change: change,
        direction: direction_for(change, invert),
        money: money
      }
    end

    def direction_for(change, invert)
      return "flat" if change.nil? || change.zero?

      improving = invert ? change.negative? : change.positive?
      improving ? "up" : "down"
    end

    def order_totals_since(from, to = nil)
      scope = Order.where(status: PAID_STATUSES).where("orders.created_at >= ?", from)
      scope = scope.where("orders.created_at < ?", to) if to
      scope.pick(
        Arel.sql("COALESCE(SUM(total_cents), 0)"),
        Arel.sql("COALESCE(SUM(commission_cents), 0)"),
        Arel.sql("COUNT(*)")
      )
    end

    def newsletter_counts(window_start, previous_start)
      quoted = ActiveRecord::Base.connection.quote(window_start)
      NewsletterSubscriber.confirmed
                          .where("created_at >= ?", previous_start)
                          .pick(
                            Arel.sql("COUNT(*) FILTER (WHERE created_at >= #{quoted})"),
                            Arel.sql("COUNT(*) FILTER (WHERE created_at < #{quoted})")
                          )
    end

    def charts
      {
        signups: daily_series(User.where("users.created_at >= ?", WINDOW.days.ago), :created_at),
        orders: daily_series(Order.where("orders.created_at >= ?", WINDOW.days.ago), :created_at),
        categories: category_series
      }
    end

    def daily_series(scope, column)
      counts = scope.group(Arel.sql("DATE(#{column})")).count
      (0...WINDOW).map do |offset|
        date = (now.to_date - (WINDOW - 1 - offset))
        [ date, counts.fetch(date, 0) ]
      end
    end

    def category_series
      counts = Listing.published
                      .joins(:category)
                      .group("categories.id")
                      .order(Arel.sql("COUNT(*) DESC"))
                      .limit(10)
                      .count
      categories = Category.where(id: counts.keys).index_by(&:id)
      counts.filter_map { |id, count| [ categories[id]&.name, count ] if categories[id] }
    end

    def tables
      {
        pending_listings: Listing.pending_review
                                 .includes(:user, :store, :category, images_attachments: :blob)
                                 .order(created_at: :asc).limit(5),
        latest_orders: Order.includes(:buyer, :seller, :store).order(created_at: :desc).limit(5),
        latest_users: User.includes(:store).order(created_at: :desc).limit(5)
      }
    end

    def health
      {
        failed_jobs: solid_queue_count { SolidQueue::FailedExecution.count },
        pending_jobs: solid_queue_count { SolidQueue::Job.where(finished_at: nil).count },
        storage_bytes: ActiveStorage::Blob.sum(:byte_size).to_i,
        database_bytes: database_bytes
      }
    end

    def solid_queue_count
      return 0 unless solid_queue_available?

      yield
    rescue NameError, ActiveRecord::StatementInvalid
      0
    end

    def solid_queue_available?
      return @solid_queue_available unless @solid_queue_available.nil?

      @solid_queue_available = defined?(SolidQueue::Job) &&
                               SolidQueue::Job.connection.data_source_exists?("solid_queue_jobs")
    end

    def database_bytes
      ActiveRecord::Base.connection.select_value("SELECT pg_database_size(current_database())").to_i
    rescue ActiveRecord::StatementInvalid
      0
    end
  end
end
