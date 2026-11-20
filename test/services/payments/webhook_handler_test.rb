require "test_helper"
require "ostruct"

# Fake events stand in for Stripe::Webhook.construct_event output (the
# controller test covers signature verification): the handler only reads
# id/type/data.object off the event, dot-access style.
class Payments::WebhookHandlerTest < ActiveSupport::TestCase
  setup do
    @gpu = publish(create_listing(price_cents: 50_000, quantity: 3, shipping_price_cents: 500))
    @orders = place
    @group = @orders.first.checkout_group
  end

  # --- checkout.session.completed ----------------------------------------------------

  test "a paid session marks the whole group paid and saves the payment intent" do
    event = session_event("checkout.session.completed", payment_status: "paid", payment_intent: "pi_999")

    assert Payments::WebhookHandler.call(event)

    @orders.each do |order|
      order.reload
      assert_predicate order, :paid?
      assert_equal "paid", order.payment_status
      assert_equal "pi_999", order.stripe_payment_intent_id
    end
    assert_equal 1, StripeEvent.where(stripe_id: "evt_1", event_type: "checkout.session.completed").count
  end

  test "an unpaid session does not mark anything paid but is still recorded" do
    event = session_event("checkout.session.completed", payment_status: "unpaid")

    assert Payments::WebhookHandler.call(event)
    assert @orders.all? { |order| order.reload.pending? }
    assert_equal 1, StripeEvent.where(stripe_id: "evt_1").count
  end

  test "a redelivered event is ignored" do
    event = session_event("checkout.session.completed", payment_status: "paid", payment_intent: "pi_999")

    assert Payments::WebhookHandler.call(event)
    assert_not Payments::WebhookHandler.call(event)
    assert_equal 1, StripeEvent.count
  end

  # --- checkout.session.expired ------------------------------------------------------

  test "an expired session cancels the pending orders and restocks" do
    event = session_event("checkout.session.expired")

    assert Payments::WebhookHandler.call(event)

    @orders.each do |order|
      order.reload
      assert_predicate order, :cancelled?
      assert_equal "payment_expired", order.cancel_reason
    end
    assert_equal 3, @gpu.reload.quantity
  end

  test "an expired session leaves already paid orders alone" do
    @orders.first.mark_paid!
    event = session_event("checkout.session.expired")

    Payments::WebhookHandler.call(event)

    assert_predicate @orders.first.reload, :paid?
  end

  # --- charge.refunded ---------------------------------------------------------------

  test "a fully refunded charge refunds the orders paid by that intent" do
    paid = @orders.first
    paid.update!(stripe_payment_intent_id: "pi_999")
    paid.mark_paid!
    event = OpenStruct.new(
      id: "evt_1", type: "charge.refunded",
      data: OpenStruct.new(object: OpenStruct.new(
        payment_intent: "pi_999", amount_captured: 50_500, amount_refunded: 50_500
      ))
    )

    assert Payments::WebhookHandler.call(event)
    assert_predicate paid.reload, :refunded?
    assert_equal "refunded", paid.payment_status
  end

  test "a partial refund leaves the order paid" do
    paid = @orders.first
    paid.update!(stripe_payment_intent_id: "pi_999")
    paid.mark_paid!
    event = OpenStruct.new(
      id: "evt_1", type: "charge.refunded",
      data: OpenStruct.new(object: OpenStruct.new(
        payment_intent: "pi_999", amount_captured: 50_500, amount_refunded: 1_000
      ))
    )

    Payments::WebhookHandler.call(event)
    assert_predicate paid.reload, :paid?
  end

  # --- account.updated ---------------------------------------------------------------

  test "account.updated syncs the flags of the matching store" do
    store = @orders.first.store
    store.update!(stripe_account_id: "acct_123")
    event = OpenStruct.new(
      id: "evt_1", type: "account.updated",
      data: OpenStruct.new(object: OpenStruct.new(
        id: "acct_123", charges_enabled: true, payouts_enabled: "false", details_submitted: true
      ))
    )

    assert Payments::WebhookHandler.call(event)

    store.reload
    assert store.stripe_charges_enabled
    assert_not store.stripe_payouts_enabled
    assert store.stripe_details_submitted
    assert_not_nil store.stripe_synced_at
  end

  test "account.updated for an unknown account is a no-op" do
    event = OpenStruct.new(
      id: "evt_1", type: "account.updated",
      data: OpenStruct.new(object: OpenStruct.new(id: "acct_nope", charges_enabled: true))
    )

    assert Payments::WebhookHandler.call(event)
    assert StripeEvent.exists?(stripe_id: "evt_1")
  end

  # --- unknown events ----------------------------------------------------------------

  test "unknown events are recorded and change nothing" do
    event = OpenStruct.new(id: "evt_1", type: "charge.succeeded",
                           data: OpenStruct.new(object: OpenStruct.new))

    assert Payments::WebhookHandler.call(event)
    assert StripeEvent.exists?(stripe_id: "evt_1", event_type: "charge.succeeded")
    assert @orders.all? { |order| order.reload.pending? }
  end

  private

  def place
    cart = Cart.create!
    cart.add(@gpu, quantity: 2)
    Orders::Placer.call(
      cart: cart, buyer: users(:pending), email: "buyer@example.com",
      shipping_address: { "first_name" => "Mauro", "street_line1" => "Calle Mayor 1",
                          "postal_code" => "28001", "city" => "Madrid", "country" => "ES" },
      shipping_method: "delivery", payment_method: "stripe"
    ).orders
  end

  def session_event(type, payment_status: nil, payment_intent: nil)
    OpenStruct.new(
      id: "evt_1", type: type,
      data: OpenStruct.new(object: OpenStruct.new(
        payment_status: payment_status, payment_intent: payment_intent,
        metadata: OpenStruct.new(checkout_group: @group)
      ))
    )
  end
end
