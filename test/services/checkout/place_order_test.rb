require "test_helper"

class CheckoutPlaceOrderTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @buyer = users(:buyer)
    @listing = listings(:published_gpu)
    @summary = CartSummary.for(user: @buyer)
  end

  test "creates one order per seller and decrements stock" do
    other_seller = create_seller("order-seller@example.com")
    other_listing = create_listing(user: other_seller, price_cents: 12_000)
    CartItem.create!(user: @buyer, listing: other_listing, quantity: 1)

    summary = CartSummary.for(user: @buyer)
    orders = Checkout::PlaceOrder.new(form: form_for(summary), summary: summary).call

    assert_equal 2, orders.size
    assert_equal 2, Order.where(checkout_token: orders.first.checkout_token).count
    assert orders.all?(&:pending_payment?)
    assert @listing.reload.sold?
    assert_equal 0, @listing.quantity
    assert other_listing.reload.sold?
    assert_empty CartItem.where(user_id: @buyer)
    assert orders.all? { |order| order.order_items.any? && order.total_cents.positive? }
    assert_equal orders.size, orders.map(&:number).uniq.size
  end

  test "snapshots commission only when commissions are enabled" do
    Setting.set("commissions_enabled", true)
    Setting.set("commission_percent", 10)

    orders = Checkout::PlaceOrder.new(form: form_for(@summary), summary: @summary).call
    order = orders.first

    assert_equal 5_490, order.commission_cents
    assert_equal BigDecimal("10.0"), order.commission_percent
    assert_equal order.subtotal_cents + order.shipping_cents, order.total_cents
  ensure
    Setting.set("commissions_enabled", false)
    Setting.set("commission_percent", 5.0)
  end

  test "leaves commission at zero when disabled" do
    orders = Checkout::PlaceOrder.new(form: form_for(@summary), summary: @summary).call

    assert_equal 0, orders.first.commission_cents
    assert_equal 0, orders.first.commission_percent
  end

  test "is idempotent for the same checkout token" do
    form = form_for(@summary)

    first = Checkout::PlaceOrder.new(form: form, summary: @summary).call
    second = Checkout::PlaceOrder.new(form: form, summary: @summary).call

    assert_equal first.map(&:id), second.map(&:id)
    assert_equal 1, Order.where(checkout_token: form.checkout_token).count
  end

  test "rejects a second attempt when stock was taken in the meantime" do
    summary = CartSummary.for(user: @buyer)
    first_form = form_for(summary)
    second_form = form_for(summary, checkout_token: SecureRandom.uuid)

    Checkout::PlaceOrder.new(form: first_form, summary: summary).call

    error = assert_raises(Checkout::PlaceOrder::Error) do
      Checkout::PlaceOrder.new(form: second_form, summary: summary).call
    end

    assert_equal "stock_changed", error.message_key
    assert_equal 1, Order.where(checkout_token: first_form.checkout_token).count
    assert_equal 0, Order.where(checkout_token: second_form.checkout_token).count
  end

  test "creates a guest order with an access token" do
    guest_listing = create_listing(user: users(:seller), price_cents: 8_000)
    CartItem.create!(cart_token: "guest-cart-token", listing: guest_listing, quantity: 1)
    summary = CartSummary.for(token: "guest-cart-token")

    order = Checkout::PlaceOrder.new(
      form: form_for(summary, user: nil, email: "guest@example.com"),
      summary: summary
    ).call.first

    assert order.guest?
    assert_nil order.buyer
    assert_equal "guest@example.com", order.buyer_email
    assert order.guest_access_token.present?
    assert_equal "bank_transfer", order.payment_method
  end

  test "uses local pickup and zero shipping when pickup is selected" do
    pickup_listing = create_listing(user: users(:seller), shipping_available: false, local_pickup: true,
                                    shipping_price_cents: 0, price_cents: 7_000)
    CartItem.create!(user: @buyer, listing: pickup_listing, quantity: 1)
    summary = CartSummary.for(user: @buyer)

    order = Checkout::PlaceOrder.new(
      form: form_for(summary, delivery: { users(:seller).id.to_s => "local_pickup" }),
      summary: summary
    ).call.find { |entry| entry.seller_id == users(:seller).id }

    assert order.local_pickup?
    assert_equal 0, order.shipping_cents
    assert_nil order.ship_line1
  end

  test "does not email the seller when order update notifications are disabled" do
    users(:seller).update!(notification_preferences: { "email_order_updates" => false })
    summary = CartSummary.for(user: @buyer)

    assert_enqueued_emails 1 do
      Checkout::PlaceOrder.new(form: form_for(summary), summary: summary).call
    end
  end

  private

  def form_for(summary, user: @buyer, email: nil, delivery: nil, checkout_token: nil)
    delivery ||= summary.groups.to_h { |group| [ group.seller.id.to_s, "shipping" ] }
    Checkout::Form.new(
      summary: summary,
      user: user,
      email: email || user&.email || "guest@example.com",
      payment_method: "bank_transfer",
      terms_accepted: "1",
      withdrawal_acknowledged: "1",
      checkout_token: checkout_token || SecureRandom.uuid,
      full_name: "Test Buyer",
      line1: "Calle de Alcalá 1",
      city: "Madrid",
      postal_code: "28001",
      region_id: regions(:madrid).id,
      country_code: "ES",
      delivery: delivery
    )
  end

  def create_seller(email)
    User.create!(
      email: email, password: "Password123!", first_name: "Other", last_name: "Seller",
      country_code: "ES", region: regions(:madrid), city: "Madrid", locale: "es",
      confirmed_at: Time.current, terms_accepted_at: Time.current
    )
  end

  def create_listing(user:, **attributes)
    Listing.create!(
      {
        user: user, category: categories(:cpus),
        title: "Test processor #{SecureRandom.hex(4)}",
        description: "A sufficiently detailed description for a test listing.",
        price_cents: 10_000, condition: :used_good, status: :published,
        published_at: Time.current, quantity: 1, country_code: "ES",
        region: regions(:madrid), city: "Madrid", postal_code: "28001",
        shipping_available: true, local_pickup: true, shipping_price_cents: 500,
        ships_within_days: 2
      }.merge(attributes)
    )
  end
end
