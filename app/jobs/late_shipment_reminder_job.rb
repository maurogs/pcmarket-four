class LateShipmentReminderJob < ApplicationJob
  queue_as :default

  def perform(now = Time.current)
    deadline_days = [ Setting.get("seller_ship_deadline_days", 3).to_i, 1 ].max
    reminder_cutoff = now - deadline_days.days
    cancellation_cutoff = now - (deadline_days * 2).days

    Order.where(status: :paid).where(shipped_at: nil).find_each do |order|
      paid_at = order.paid_at || order.updated_at
      next if paid_at > reminder_cutoff

      if paid_at <= cancellation_cutoff
        order.cancel!(nil, "seller_late_shipment", refund_required: true)
      else
        order.flag_late_shipment!
      end
    end
  end
end
