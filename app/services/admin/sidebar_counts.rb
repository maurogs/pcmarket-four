module Admin
  # Sidebar counters for operational queues. Cached for one minute so every
  # admin page load does not re-count the same rows.
  class SidebarCounts
    CACHE_KEY = "admin/sidebar_counts/v1"
    TTL = 1.minute

    def self.call
      Rails.cache.fetch(CACHE_KEY, expires_in: TTL) { new.call }
    end

    def call
      {
        open_disputes: Order.disputed.count,
        open_reports: Report.open.count,
        pending_payments: Order.pending_payment.where(payment_method: "bank_transfer").count
      }
    end
  end
end
