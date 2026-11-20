require "test_helper"

class Orders::ExpireUnpaidJobTest < ActiveSupport::TestCase
  setup do
    @store = Store.create!(user: users(:pending), name: "Seller Store", country: countries(:es))
    @listing = publish(create_listing(store: @store, price_cents: 10_000, quantity: 5))
  end

  test "cancels pending manual orders past the reservation window and restocks" do
    order = place_order
    order.update_column(:placed_at, Orders::ExpireUnpaidJob::RESERVATION_HOURS.hours.ago - 1.hour)

    Orders::ExpireUnpaidJob.new.perform

    order.reload
    assert_predicate order, :cancelled?
    assert_equal "expired", order.cancel_reason
    assert_equal 5, @listing.reload.quantity
  end

  test "leaves orders inside the window, paid orders and stripe orders alone" do
    fresh = place_order
    paid = place_order.tap { |o| o.update!(status: "paid", paid_at: Time.current) }
    stripe = place_order.tap { |o| o.update_column(:payment_method, "stripe") }
    [ fresh, paid, stripe ].each { |o| o.update_column(:placed_at, 100.hours.ago) }
    fresh.update_column(:placed_at, 1.hour.ago)

    Orders::ExpireUnpaidJob.new.perform

    assert_predicate fresh.reload, :pending?
    assert_predicate paid.reload, :paid?
    assert_predicate stripe.reload, :pending?
    assert_equal 2, @listing.reload.quantity
  end

  private

  def place_order
    cart = Cart.create!
    cart.add(@listing)
    result = Orders::Placer.call(
      cart: cart, buyer: nil, email: "buyer@example.com",
      shipping_address: { first_name: "Mauro", last_name: "Lopez", street_line1: "Calle Mayor 1",
                          postal_code: "28001", city: "Madrid", province: "28" },
      shipping_method: "delivery", payment_method: "manual"
    )
    assert_predicate result, :success?, result.errors.join(" ")
    result.orders.first
  end
end
