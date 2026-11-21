require "test_helper"

class OrderLifecycleJobsTest < ActiveJob::TestCase
  setup do
    Setting.set("inspection_window_days", 2)
    Setting.set("auto_complete_after_delivery_days", 2)
    Setting.set("auto_delivered_after_shipping_days", 14)
    Setting.set("seller_ship_deadline_days", 3)
  end

  test "auto deliver marks old shipments delivered" do
    old = create_order(status: :shipped)
    old.update_columns(shipped_at: 20.days.ago)
    recent = create_order(status: :shipped)
    recent.update_columns(shipped_at: 2.days.ago)

    AutoDeliverOrdersJob.perform_now

    assert old.reload.delivered?
    assert recent.reload.shipped?
  end

  test "auto complete skips disputed orders" do
    delivered = create_order(status: :delivered)
    delivered.update_columns(delivered_at: 5.days.ago)
    disputed = create_order(status: :disputed)
    disputed.update_columns(delivered_at: 5.days.ago, disputed_at: 4.days.ago)

    AutoCompleteOrdersJob.perform_now

    assert delivered.reload.completed?
    assert disputed.reload.disputed?
  end

  test "late shipment reminder notifies the seller once" do
    order = create_order(status: :paid)
    order.update_columns(paid_at: 4.days.ago)

    assert_difference -> { order.seller.notifications.where(kind: "order_late_shipment").count }, 1 do
      LateShipmentReminderJob.perform_now
    end

    assert order.reload.late_shipment_notified_at.present?
    assert_no_difference -> { order.seller.notifications.where(kind: "order_late_shipment").count } do
      LateShipmentReminderJob.perform_now
    end
  end

  test "late shipment job auto-cancels at twice the deadline with a refund flag" do
    order = create_order(status: :paid)
    order.update_columns(paid_at: 7.days.ago)
    buyer_kind = "order_cancelled"
    seller_kind = "order_cancelled_seller"

    assert_difference -> { Notification.where(kind: [ buyer_kind, seller_kind ]).count }, 2 do
      LateShipmentReminderJob.perform_now
    end

    order.reload
    assert order.cancelled?
    assert order.refund_required?
    assert_equal "seller_late_shipment", order.cancel_reason
  end
end
