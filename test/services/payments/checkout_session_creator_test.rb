require "test_helper"
require "minitest/mock"
require "ostruct"

# Stripe is never called for real: Checkout::Session.create is stubbed with
# an OpenStruct stand-in (the service only reads .id off the response). The
# orders under test are real — placed through Orders::Placer.
class Payments::CheckoutSessionCreatorTest < ActiveSupport::TestCase
  SUCCESS_URL = "https://pcmarket.test/es/checkout_confirmations/g?session_id={CHECKOUT_SESSION_ID}"
  CANCEL_URL = "https://pcmarket.test/es/cart"

  setup do
    @gpu = publish(create_listing(price_cents: 50_000, quantity: 3, shipping_price_cents: 500))
    @orders = place_orders(@gpu)
  end

  # --- happy path ------------------------------------------------------------------

  test "creates a payment session with one line per item plus the shipping line" do
    calls = []
    outcome = create_session(calls) do
      Payments::CheckoutSessionCreator.call(@orders, success_url: SUCCESS_URL, cancel_url: CANCEL_URL)
    end

    assert_predicate outcome, :success?
    params = calls.first.first
    assert_equal "payment", params[:mode]
    assert_equal "buyer@example.com", params[:customer_email]
    assert_equal SUCCESS_URL, params[:success_url]
    assert_equal CANCEL_URL, params[:cancel_url]

    lines = params[:line_items]
    assert_equal 2, lines.size
    item, shipping = lines
    assert_equal 2, item[:quantity]
    assert_equal "eur", item[:price_data][:currency]
    assert_equal 50_000, item[:price_data][:unit_amount]
    assert_equal @gpu.title, item[:price_data][:product_data][:name]
    assert_equal 1, shipping[:quantity]
    assert_equal 500, shipping[:price_data][:unit_amount]
    assert_includes shipping[:price_data][:product_data][:name], @orders.first.store.name
  end

  test "orders without shipping cost get no shipping line" do
    free = publish(create_listing(price_cents: 9_000, quantity: 2, free_shipping: true))
    orders = place_orders(free)

    calls = []
    create_session(calls) do
      Payments::CheckoutSessionCreator.call(orders, success_url: SUCCESS_URL, cancel_url: CANCEL_URL)
    end

    assert_equal 1, calls.first.first[:line_items].size
  end

  test "the group is set as transfer group and metadata, and the idempotency key derives from it" do
    calls = []
    group = @orders.first.checkout_group
    create_session(calls) do
      Payments::CheckoutSessionCreator.call(@orders, success_url: SUCCESS_URL, cancel_url: CANCEL_URL)
    end

    params, options = calls.first
    assert_equal group, params[:payment_intent_data][:transfer_group]
    assert_equal({ checkout_group: group }, params[:payment_intent_data][:metadata])
    assert_equal({ checkout_group: group }, params[:metadata])
    assert_equal "checkout-#{group}", options[:idempotency_key]
  end

  test "the session expires in half an hour and uses the Stripe locale for the request" do
    calls = []
    I18n.with_locale(:pt) do
      create_session(calls) do
        Payments::CheckoutSessionCreator.call(@orders, success_url: SUCCESS_URL, cancel_url: CANCEL_URL)
      end
    end

    params = calls.first.first
    assert_in_delta (Time.current + 30.minutes).to_i, params[:expires_at], 5
    assert_equal "pt-PT", params[:locale]
  end

  test "the session id is stamped on every order of the group" do
    create_session do
      Payments::CheckoutSessionCreator.call(@orders, success_url: SUCCESS_URL, cancel_url: CANCEL_URL)
    end

    assert_equal [ "cs_test_1" ], @orders.map { |o| o.reload.stripe_checkout_session_id }.uniq
  end

  # --- failures --------------------------------------------------------------------

  test "a Stripe error becomes a translated failure and stamps nothing" do
    Stripe::Checkout::Session.stub(:create, ->(*) { raise Stripe::StripeError, "boom" }) do
      outcome = Payments::CheckoutSessionCreator.call(
        @orders, success_url: SUCCESS_URL, cancel_url: CANCEL_URL
      )
      assert_not_predicate outcome, :success?
      assert_equal I18n.t("payments.checkout.stripe_error"), outcome.errors.first
    end

    assert_nil @orders.first.reload.stripe_checkout_session_id
  end

  test "an empty order list fails without calling Stripe" do
    Stripe::Checkout::Session.stub(:create, ->(*) { flunk "must not call Stripe" }) do
      outcome = Payments::CheckoutSessionCreator.call(
        [], success_url: SUCCESS_URL, cancel_url: CANCEL_URL
      )
      assert_not_predicate outcome, :success?
      assert_equal I18n.t("payments.checkout.no_orders"), outcome.errors.first
    end
  end

  private

  def place_orders(*listings)
    cart = Cart.create!
    listings.each { |listing| cart.add(listing, quantity: listing == @gpu ? 2 : 1) }
    Orders::Placer.call(
      cart: cart, buyer: users(:pending), email: "buyer@example.com",
      shipping_address: { "first_name" => "Mauro", "street_line1" => "Calle Mayor 1",
                          "postal_code" => "28001", "city" => "Madrid", "country" => "ES" },
      shipping_method: "delivery", payment_method: "stripe"
    ).orders
  end

  # Runs the block with Session.create stubbed; returns the service outcome.
  def create_session(calls = nil)
    session = OpenStruct.new(id: "cs_test_1", url: "https://checkout.stripe.com/pay/cs_test_1")
    stub = lambda do |params, options|
      calls&.<<([ params, options ])
      session
    end
    Stripe::Checkout::Session.stub(:create, stub) { yield }
  end
end
