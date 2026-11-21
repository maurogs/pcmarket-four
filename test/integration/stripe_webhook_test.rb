require "test_helper"

class StripeWebhookTest < ActionDispatch::IntegrationTest
  setup do
    @secret = "whsec_test_secret"
    @previous_secret = ENV["STRIPE_WEBHOOK_SECRET"]
    ENV["STRIPE_WEBHOOK_SECRET"] = @secret
  end

  teardown do
    ENV["STRIPE_WEBHOOK_SECRET"] = @previous_secret
  end

  test "rejects an invalid signature with 400" do
    post stripe_webhook_path, params: { id: "evt_test" }.to_json,
         headers: { "CONTENT_TYPE" => "application/json", "HTTP_STRIPE_SIGNATURE" => "t=1,v1=bad" }

    assert_response :bad_request
  end

  test "marks orders paid idempotently when checkout completes" do
    order = orders(:pending_order)
    order.update!(payment_method: "stripe", payment_provider: "stripe")
    event = checkout_event("checkout.session.completed", order, payment_intent: "pi_test_999")

    with_webhook_event(event) do
      post_stripe_webhook
      assert_response :success
    end

    order.reload
    assert order.paid?
    assert_equal "pi_test_999", order.payment_reference
    paid_at = order.paid_at
    assert_not_nil paid_at

    with_webhook_event(event) do
      post_stripe_webhook
      assert_response :success
    end

    order.reload
    assert_equal paid_at, order.paid_at
    assert_equal 1, Order.where(payment_reference: "pi_test_999").count
  end

  test "cancels the order and restores stock when the session expires" do
    order = orders(:pending_order)
    order.update!(payment_method: "stripe", payment_provider: "stripe")
    listing = listings(:published_gpu)
    order.order_items.create!(listing: listing, title_snapshot: listing.title,
                              price_cents: listing.price_cents, quantity: 1)
    listing.update_columns(quantity: 0, status: Listing.statuses[:sold], updated_at: Time.current)
    event = checkout_event("checkout.session.expired", order)

    with_webhook_event(event) do
      post_stripe_webhook
      assert_response :success
    end

    assert order.reload.cancelled?
    assert listing.reload.published?
    assert_equal 1, listing.quantity
  end

  private

  def post_stripe_webhook
    post stripe_webhook_path, params: { id: "evt_test", type: "checkout.session.completed" }.to_json,
         headers: { "CONTENT_TYPE" => "application/json", "HTTP_STRIPE_SIGNATURE" => "t=1,v1=stubbed" }
  end

  def checkout_event(type, order, payment_intent: nil)
    session = Struct.new(:id, :payment_intent, :metadata).new(
      "cs_test_#{SecureRandom.hex(4)}", payment_intent, { "order_ids" => order.id.to_s }
    )
    Struct.new(:type, :data).new(type, Struct.new(:object).new(session))
  end

  def with_webhook_event(event)
    original = ::Stripe::Webhook.method(:construct_event)
    ::Stripe::Webhook.define_singleton_method(:construct_event) { |*_args| event }
    yield
  ensure
    ::Stripe::Webhook.define_singleton_method(:construct_event, original)
  end
end
