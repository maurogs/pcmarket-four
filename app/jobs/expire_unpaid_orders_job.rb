class ExpireUnpaidOrdersJob < ApplicationJob
  queue_as :default

  def perform(now = Time.current)
    deadline_days = Setting.get("payment_deadline_days", 3).to_i
    cutoff = now - [ deadline_days, 1 ].max.days

    Order.where(status: :pending_payment, payment_method: "bank_transfer")
         .where("created_at < ?", cutoff)
         .find_each do |order|
      order.cancel_unpaid!(reason: "payment_expired")
    end
  end
end
