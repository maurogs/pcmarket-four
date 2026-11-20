require "test_helper"
require "minitest/mock"
require "ostruct"

# POST /webhooks/stripe (Phase 4 step 4b). construct_event is stubbed — the
# real signature verification is Stripe gem's job — so these tests cover the
# controller contract: 400 on unverifiable payloads, 200 + delegation
# otherwise, and idempotency across redeliveries.
class StripeWebhooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @gpu = publish(create_listing(price_cents: 50_000, quantity: 3, shipping_price_cents: 500))
    @orders = place
    @group = @orders.first.checkout_group
  end

  test "an invalid signature is rejected with 400 and stores nothing" do
    Stripe::Webhook.stub(:construct_event, ->(*) { raise Stripe::SignatureVerificationError.new("bad sig", "t=1,v1=x") }) do
      post webhook_path, params: event_body, headers: webhook_headers
    end

    assert_response :bad_request
    assert_equal 0, StripeEvent.count
    assert @orders.all?(&:pending?)
  end

  test "a malformed body is rejected with 400" do
    Stripe::Webhook.stub(:construct_event, ->(*) { raise JSON::ParserError, "unexpected token" }) do
      post webhook_path, params: "{not json", headers: webhook_headers
    end

    assert_response :bad_request
  end

  test "a completed session marks the group paid and answers 200" do
    stub_event completed_event do
      post webhook_path, params: event_body, headers: webhook_headers
    end

    assert_response :ok
    assert @orders.all? { |order| order.reload.paid? }
    assert_equal "pi_999", @orders.first.stripe_payment_intent_id
    assert_equal 1, StripeEvent.count
  end

  test "a redelivered event is answered 200 but applied only once" do
    stub_event completed_event do
      post webhook_path, params: event_body, headers: webhook_headers
      post webhook_path, params: event_body, headers: webhook_headers
    end

    assert_response :ok
    assert_equal 1, StripeEvent.count
    assert_equal 1, Order.where(status: "paid").count
  end

  test "an expired session cancels and restocks" do
    stub_event session_event("checkout.session.expired") do
      post webhook_path, params: event_body, headers: webhook_headers
    end

    assert_response :ok
    assert @orders.all? { |order| order.reload.cancelled? }
    assert_equal 3, @gpu.reload.quantity
  end

  test "account.updated syncs the store flags" do
    store = @orders.first.store
    store.update!(stripe_account_id: "acct_123")
    event = OpenStruct.new(
      id: "evt_1", type: "account.updated",
      data: OpenStruct.new(object: OpenStruct.new(
        id: "acct_123", charges_enabled: true, payouts_enabled: true, details_submitted: true
      ))
    )

    stub_event event do
      post webhook_path, params: event_body, headers: webhook_headers
    end

    assert_response :ok
    assert store.reload.stripe_charges_enabled
  end

  test "unknown events are acknowledged with 200" do
    event = OpenStruct.new(id: "evt_1", type: "charge.succeeded", data: OpenStruct.new(object: OpenStruct.new))

    stub_event event do
      post webhook_path, params: event_body, headers: webhook_headers
    end

    assert_response :ok
    assert StripeEvent.exists?(stripe_id: "evt_1", event_type: "charge.succeeded")
  end

  private

  def webhook_path
    "/webhooks/stripe"
  end

  def webhook_headers
    { "Stripe-Signature" => "t=1700000000,v1=stubbed" }
  end

  def event_body
    '{"id":"evt_1","type":"test"}'
  end

  def stub_event(event)
    Stripe::Webhook.stub(:construct_event, ->(*) { event }) { yield }
  end

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

  def completed_event
    session_event("checkout.session.completed", payment_status: "paid", payment_intent: "pi_999")
  end
end
