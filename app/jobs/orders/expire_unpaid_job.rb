# Manual-payment reservation expiry (Phase 4 step 3): a pending manual
# order that was not paid within the 48h reservation window is cancelled
# with reason "expired", which restocks its listings (Order#cancel runs
# #apply_cancellation). Scheduled hourly through config/recurring.yml
# (Solid Queue recurring tasks).
module Orders
  class ExpireUnpaidJob < ApplicationJob
    queue_as :default

    RESERVATION_HOURS = 48

    def perform
      expired.find_each { |order| order.cancel!("expired") }
    end

    private

    def expired
      Order.where(status: "pending", payment_method: "manual")
           .where(placed_at: ..RESERVATION_HOURS.hours.ago)
    end
  end
end
