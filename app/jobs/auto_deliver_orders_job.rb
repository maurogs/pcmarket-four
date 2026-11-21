class AutoDeliverOrdersJob < ApplicationJob
  queue_as :default

  def perform(now = Time.current)
    days = [ Setting.get("auto_delivered_after_shipping_days", 14).to_i, 1 ].max
    cutoff = now - days.days

    Order.where(status: :shipped).where("shipped_at <= ?", cutoff).find_each do |order|
      order.confirm_delivery!(nil, automatic: true)
    end
  end
end
