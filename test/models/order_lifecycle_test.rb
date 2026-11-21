require "test_helper"

class OrderLifecycleTest < ActiveSupport::TestCase
  setup do
    Setting.set("inspection_window_days", 2)
    Setting.set("auto_complete_after_delivery_days", 2)
    Setting.set("auto_delivered_after_shipping_days", 14)
    Setting.set("seller_ship_deadline_days", 3)
    @admin = users(:admin)
    @seller = users(:seller)
    @buyer = users(:buyer)
  end

  test "admin marks a pending order as paid and writes an event" do
    order = create_order

    assert order.mark_paid!(@admin, reference: "pi_123", provider: "stripe")
    assert order.reload.paid?
    assert order.paid_at.present?
    assert_equal "pi_123", order.payment_reference
    assert_equal %w[placed paid], order.order_events.chronological.pluck(:kind)
  end

  test "seller can mark cash-on-pickup paid but not a card order" do
    cash = create_order(payment_method: "cash_on_pickup", fulfilment: :local_pickup)
    card = create_order(payment_method: "stripe")

    assert cash.mark_paid!(@seller)
    assert cash.reload.paid?
    assert_not card.mark_paid!(@seller)
    assert card.reload.pending_payment?
  end

  test "another user cannot mark an order as paid" do
    order = create_order(payment_method: "cash_on_pickup", fulfilment: :local_pickup)

    assert_not order.mark_paid!(users(:moderator))
    assert order.reload.pending_payment?
  end

  test "seller ships a paid order with a valid carrier and tracking" do
    order = create_order(status: :paid)

    assert order.ship!(@seller, carrier: "seur", tracking_number: "SE123")
    assert order.reload.shipped?
    assert_equal "seur", order.carrier
    assert_equal "SE123", order.tracking_number
    assert_match(/seur\.com/, order.tracking_url)
    assert_equal "shipped", order.order_events.chronological.last.kind
  end

  test "shipping requires a tracking number unless the carrier is other" do
    order = create_order(status: :paid)

    assert_not order.ship!(@seller, carrier: "seur", tracking_number: "")
    assert_not order.ship!(@seller, carrier: "spaceship", tracking_number: "X")
    assert order.reload.paid?
    assert order.ship!(@seller, carrier: "other", tracking_number: "")
  end

  test "only the seller can ship" do
    order = create_order(status: :paid)

    assert_not order.ship!(@buyer, carrier: "seur", tracking_number: "SE1")
    assert order.reload.paid?
  end

  test "local pickup is marked ready without tracking" do
    order = create_order(status: :paid, fulfilment: :local_pickup)

    assert order.mark_ready_for_pickup!(@seller)
    assert order.reload.shipped?
    assert_nil order.tracking_number
    assert_equal "ready_for_pickup", order.order_events.chronological.last.kind
  end

  test "buyer confirms delivery and automatic delivery uses no actor" do
    order = create_order(status: :shipped)

    assert_not order.confirm_delivery!(@seller)
    assert order.confirm_delivery!(@buyer)
    assert order.reload.delivered?

    automatic = create_order(status: :shipped)
    assert automatic.confirm_delivery!(nil, automatic: true)
    assert automatic.reload.delivered?
    assert automatic.order_events.chronological.last.actor_id.nil?
  end

  test "completion waits for the inspection window and increments sales count" do
    store = stores(:seller_store)
    before = store.sales_count
    fresh = create_order(status: :delivered)
    fresh.update_columns(delivered_at: Time.current)
    assert_not fresh.complete!

    order = create_order(status: :delivered)
    order.update_columns(delivered_at: 3.days.ago)

    assert order.complete!(@admin)
    assert order.reload.completed?
    assert_equal before + 1, store.reload.sales_count
    assert_equal "completed", order.order_events.chronological.last.kind
  end

  test "cancelling a pending order restores stock and relists a sold listing" do
    listing = listings(:published_gpu)
    listing.update_columns(quantity: 0, status: Listing.statuses[:sold], updated_at: Time.current)
    order = create_order(listing: listing)

    assert order.cancel!(@buyer, "changed_mind")
    order.reload

    assert order.cancelled?
    assert_equal "changed_mind", order.cancel_reason
    assert listing.reload.published?
    assert_equal 1, listing.quantity
    assert order.stock_restored_at.present?
    assert_not order.cancel!(@buyer, "again")
  end

  test "a seller cancelling a paid order flags a refund and restores stock" do
    listing = listings(:published_gpu)
    listing.update_columns(quantity: 0, status: Listing.statuses[:sold], updated_at: Time.current)
    order = create_order(status: :paid, listing: listing)

    assert order.cancel!(@seller, "out_of_stock")
    order.reload

    assert order.cancelled?
    assert order.refund_required?
    assert_equal 1, listing.reload.quantity
    assert_equal "cancelled", order.order_events.chronological.last.kind
  end

  test "buyers cannot cancel paid orders" do
    order = create_order(status: :paid)

    assert_not order.cancel!(@buyer, "nope")
    assert order.reload.paid?
  end

  test "buyer opens a dispute inside the window and admin resolves it" do
    order = create_order(status: :shipped, fulfilment: :shipping)
    order.update_columns(shipped_at: 1.day.ago)

    assert order.open_dispute!(@buyer, "damaged", "The box was crushed")
    order.reload

    assert order.disputed?
    event = order.order_events.chronological.last
    assert_equal "dispute_opened", event.kind
    assert_equal "damaged", event.data["reason"]
    assert_equal "The box was crushed", event.data["details"]

    assert order.resolve_dispute!(@admin, outcome: "refund")
    assert order.reload.refunded?
    assert order.refunded_at.present?
  end

  test "disputes are rejected outside the inspection window and for other users" do
    old = create_order(status: :shipped)
    old.update_columns(shipped_at: 5.days.ago)
    assert_not old.open_dispute!(@buyer, "damaged", "late")

    fresh = create_order(status: :shipped)
    fresh.update_columns(shipped_at: 1.day.ago)
    assert_not fresh.open_dispute!(@seller, "damaged", "not mine")
    assert_not fresh.open_dispute!(@buyer, "nonsense", "bad reason")
  end

  test "resolving a dispute by release completes the order" do
    store = stores(:seller_store)
    before = store.sales_count
    order = create_order(status: :disputed)
    order.update_columns(disputed_at: Time.current)

    assert order.resolve_dispute!(@admin, outcome: "release")
    assert order.reload.completed?
    assert_equal before + 1, store.reload.sales_count
    assert_equal "dispute_resolved", order.order_events.chronological.last.kind
  end

  test "an admin can refund a paid order and stock returns when it was not shipped" do
    listing = listings(:published_gpu)
    listing.update_columns(quantity: 0, status: Listing.statuses[:sold], updated_at: Time.current)
    order = create_order(status: :paid, listing: listing)

    assert order.refund!(@admin)
    assert order.reload.refunded?
    assert_equal 1, listing.reload.quantity
    assert_not order.refund!(@admin)
  end

  test "late shipment reminder is recorded once" do
    order = create_order(status: :paid)
    order.update_columns(paid_at: 4.days.ago)

    assert order.flag_late_shipment!
    assert order.reload.late_shipment_notified_at.present?
    assert_not order.flag_late_shipment!
    assert_equal 1, order.order_events.where(kind: "late_shipment_reminder").count
  end

  test "timeline is built from order events" do
    order = create_order
    order.mark_paid!(@admin)

    assert_equal %w[placed paid], order.timeline.map { |step| step[:key] }
  end
end
