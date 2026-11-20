require "test_helper"

class OrderTest < ActiveSupport::TestCase
  setup do
    @buyer = users(:pending)
    @seller = users(:confirmed)
    @listing = publish(create_listing(price_cents: 50_000, quantity: 3, shipping_price_cents: 500))
  end

  # --- number --------------------------------------------------------------------

  test "a number is generated on create in the PCM-YYMM-XXXXXX format" do
    order = create_order

    assert_match(/\APCM-\d{4}-\d{6}\z/, order.number)
    assert_equal "PCM-#{Time.current.strftime("%y%m")}-", order.number[0, 9]
  end

  test "numbers must be unique" do
    order = create_order

    duplicate = Order.new(order_attributes.merge(number: order.number))
    assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
  end

  # --- state machine ---------------------------------------------------------------

  test "a fresh order is pending and unpaid" do
    order = create_order

    assert_predicate order, :pending?
    assert_equal "unpaid", order.payment_status
  end

  test "mark_paid stamps paid_at and flips the payment status" do
    order = create_order

    order.mark_paid!

    assert_predicate order, :paid?
    assert_in_delta Time.current.to_f, order.paid_at.to_f, 5
    assert_equal "paid", order.payment_status
  end

  test "ship requires a tracking number unless the order is pickup" do
    order = create_order(shipping_method: "delivery")
    order.mark_paid!

    error = assert_raises(ActiveRecord::RecordInvalid) { order.ship! }
    assert_match(/tracking/i, error.message)

    # The failed save! leaves the state dirty in memory — reload first.
    order = order.reload
    order.ship!(tracking_number: "TRK123", tracking_carrier: "SEUR")

    assert_predicate order, :shipped?
    assert_in_delta Time.current.to_f, order.shipped_at.to_f, 5
    assert_equal "TRK123", order.tracking_number
    assert_equal "SEUR", order.tracking_carrier
  end

  test "a pickup order ships without tracking" do
    order = create_order(shipping_method: "pickup")
    order.mark_paid!

    order.ship!

    assert_predicate order, :shipped?
    assert_nil order.tracking_number
  end

  test "confirm_delivery stamps delivered_at and the auto-complete deadline" do
    order = shipped_order

    order.confirm_delivery!

    assert_predicate order, :delivered?
    assert_in_delta Time.current.to_f, order.delivered_at.to_f, 5
    assert_in_delta (order.delivered_at + 2.days).to_f, order.auto_complete_at.to_f, 5
  end

  test "the auto-complete deadline follows the buyer_protection_days setting" do
    set_setting("buyer_protection_days", 5, value_type: "integer")
    order = shipped_order

    order.confirm_delivery!

    assert_in_delta (order.delivered_at + 5.days).to_f, order.auto_complete_at.to_f, 5
  end

  test "complete stamps completed_at" do
    order = delivered_order

    order.complete!

    assert_predicate order, :completed?
    assert_in_delta Time.current.to_f, order.completed_at.to_f, 5
  end

  test "cancel stores the reason and timestamp" do
    order = create_order

    order.cancel!("Ordered by mistake")

    assert_predicate order, :cancelled?
    assert_equal "Ordered by mistake", order.cancel_reason
    assert_in_delta Time.current.to_f, order.cancelled_at.to_f, 5
  end

  test "refund stamps refunded_at and marks the payment refunded" do
    order = create_order
    order.mark_paid!

    order.refund!

    assert_predicate order, :refunded?
    assert_in_delta Time.current.to_f, order.refunded_at.to_f, 5
    assert_equal "refunded", order.payment_status
  end

  test "disputes open from shipped or delivered and resolve either way" do
    shipped = shipped_order
    shipped.open_dispute!
    assert_predicate shipped, :disputed?

    delivered = delivered_order
    delivered.open_dispute!
    delivered.resolve_dispute!(outcome: "completed")
    assert_predicate delivered, :completed?

    shipped.resolve_dispute!(outcome: "refunded")
    assert_predicate shipped, :refunded?
    assert_equal "refunded", shipped.payment_status
  end

  test "invalid transitions raise" do
    order = create_order

    assert_raises(AASM::InvalidTransition) { order.ship! }
    assert_raises(AASM::InvalidTransition) { order.confirm_delivery! }
    assert_raises(AASM::InvalidTransition) { order.refund! }
    assert_raises(AASM::InvalidTransition) { order.open_dispute! }

    order.mark_paid!
    order.ship!(tracking_number: "TRK1")
    assert_raises(AASM::InvalidTransition) { order.cancel! }
  end

  # --- restock -----------------------------------------------------------------------

  test "cancelling a pending order puts the units back on sale" do
    order = create_order
    add_item(order, @listing, quantity: 2)
    @listing.update!(quantity: 1) # the Placer would have decremented at placement

    order.cancel!

    assert_equal 3, @listing.reload.quantity
    assert_predicate @listing, :published?
  end

  test "cancelling an order that sold the listing relists it" do
    order = create_order
    add_item(order, @listing, quantity: 3, sold_listing: true)
    @listing.mark_sold!

    order.cancel!

    @listing.reload
    assert_predicate @listing, :published?
    assert_equal 3, @listing.quantity
  end

  test "cancelling a paid order restocks too" do
    order = create_order
    add_item(order, @listing, quantity: 1)
    @listing.update!(quantity: 2)
    order.mark_paid!

    order.cancel!

    assert_equal 3, @listing.reload.quantity
  end

  test "refunding before shipment restocks; after shipment it does not" do
    before = create_order
    add_item(before, @listing, quantity: 1)
    @listing.update!(quantity: 2)
    before.mark_paid!
    before.refund!
    assert_equal 3, @listing.reload.quantity

    after = create_order
    add_item(after, @listing, quantity: 1)
    @listing.update!(quantity: 2)
    after.mark_paid!
    after.ship!(tracking_number: "TRK1")
    after.refund!
    assert_equal 2, @listing.reload.quantity
  end

  test "restocking skips items whose listing was deleted" do
    order = create_order
    add_item(order, @listing, quantity: 1)
    @listing.order_items.update_all(listing_id: nil)

    assert_nothing_raised { order.cancel! }
    assert_predicate order, :cancelled?
  end

  # --- permissions ---------------------------------------------------------------------

  test "buyer? seller? and can_be_cancelled_by?" do
    order = create_order

    assert order.buyer?(@buyer)
    assert_not order.buyer?(@seller)
    assert order.seller?(@seller)
    assert_not order.seller?(@buyer)
    assert order.can_be_cancelled_by?(@buyer)
    assert_not order.can_be_cancelled_by?(@seller)

    order.mark_paid!
    order.ship!(tracking_number: "TRK1")
    assert_not order.can_be_cancelled_by?(@buyer)
  end

  test "a guest order has no buyer but keeps the email" do
    order = Order.create!(order_attributes.merge(buyer: nil, buyer_email: "guest@example.com"))

    assert_nil order.buyer_id
    assert_not order.buyer?(@buyer)
    assert_not order.can_be_cancelled_by?(nil)
  end

  # --- scopes ------------------------------------------------------------------------------

  test "for_buyer and for_store scopes" do
    mine = create_order
    other_buyer = create_order(buyer: @seller)
    foreign = Store.create!(user: @buyer, name: "Buyer Shop", country: countries(:es))
    elsewhere = create_order(store: foreign, buyer: @seller)

    assert_equal [ mine ], Order.for_buyer(@buyer).to_a
    assert_equal [ mine, other_buyer ].map(&:id).sort,
      Order.for_store(stores(:confirmed_store)).pluck(:id).sort
    assert_equal [ elsewhere ], Order.for_store(foreign).to_a
  end

  private

  def order_attributes
    {
      store: stores(:confirmed_store),
      buyer: @buyer,
      buyer_email: @buyer.email,
      payment_method: "manual",
      shipping_method: "delivery",
      shipping_address: { "city" => "Madrid", "postal_code" => "28001" }
    }
  end

  def create_order(**overrides)
    Order.create!(order_attributes.merge(overrides))
  end

  def add_item(order, listing, quantity: 1, sold_listing: false)
    order.order_items.create!(
      listing: listing, title: listing.title,
      unit_price_cents: listing.price_cents, quantity: quantity,
      line_total_cents: quantity * listing.price_cents,
      condition: listing.condition, sold_listing: sold_listing
    )
  end

  def shipped_order
    order = create_order
    add_item(order, @listing)
    order.mark_paid!
    order.ship!(tracking_number: "TRK123")
    order
  end

  def delivered_order
    order = shipped_order
    order.confirm_delivery!
    order
  end
end
