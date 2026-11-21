class AutoCompleteOrdersJob < ApplicationJob
  queue_as :default

  def perform(now = Time.current)
    days = [ Setting.get("inspection_window_days", 2).to_i, 1 ].max
    cutoff = now - days.days

    Order.where(status: :delivered).where("delivered_at <= ?", cutoff).find_each do |order|
      order.complete!(nil, force: true)
    end
  end
end
