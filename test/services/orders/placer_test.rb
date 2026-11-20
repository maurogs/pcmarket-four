require "test_helper"

class Orders::PlacerTest < ActiveSupport::TestCase
  setup do
    @buyer = users(:pending)
    @cart = Cart.create!
    @address = {
      "first_name" => "Mauro", "last_name" => "Lopez",
      "street_line1" => "Calle Mayor 1", "postal_code" => "28001",
      "city" => "Madrid", "country" => "ES"
    }
    # @gpu belongs to confirmed_store (users(:confirmed)); the cart is a
    # guest cart so the own-listing guard never applies here.
    @gpu = publish(create_listing(price_cents: 50_000, quantity: 3, shipping_price_cents: 500))
  end

  # --- happy path ------------------------------------------------------------------

  test "places one order per store sharing a checkout group" do
    other_store = Store.create!(user: @buyer, name: "Alpha Store", country: countries(:es))
    cpu = publish(create_listing(store: other_store, title: "Intel Core i5-12400 Processor",
                                 price_cents: 12_900, quantity: 2, free_shipping: true))
    @cart.add(@gpu, quantity: 2)
    @cart.add(cpu, quantity: 1)

    result = place

    assert_predicate result, :success?, result.errors.join(", ")
    assert_equal 2, result.orders.size
    assert_equal [ other_store.id, stores(:confirmed_store).id ].sort, result.orders.map(&:store_id)
    assert_equal [ result.checkout_group ], result.orders.map(&:checkout_group).uniq

    gpu_order = result.orders.find { |o| o.store_id == stores(:confirmed_store).id }
    assert_equal 1, gpu_order.order_items.size
    assert_equal 2, gpu_order.order_items.first.quantity
    cpu_order = result.orders.find { |o| o.store_id == other_store.id }
    assert_equal [ cpu.id ], cpu_order.order_items.map(&:listing_id)
  end

  test "snapshots totals, shipping and the buyer" do
    @cart.add(@gpu, quantity: 2)

    order = place.orders.first

    assert_equal "pending", order.status
    assert_equal "unpaid", order.payment_status
    assert_equal "manual", order.payment_method
    assert_equal "delivery", order.shipping_method
    assert_equal @buyer.email, order.buyer_email
    assert_equal @buyer.id, order.buyer_id
    assert_equal "EUR", order.currency
    assert_equal 100_000, order.subtotal_cents
    assert_equal 500, order.shipping_cents # one fee per listing, not per unit
    assert_equal 0, order.discount_cents
    assert_equal 100_500, order.total_cents
    assert_equal 0, order.commission_cents
    assert_equal @address, order.shipping_address
    assert_not_nil order.placed_at
    assert_equal I18n.locale.to_s, order.locale

    item = order.order_items.first
    assert_equal @gpu.id, item.listing_id
    assert_equal @gpu.title, item.title
    assert_equal 50_000, item.unit_price_cents
    assert_equal 2, item.quantity
    assert_equal 100_000, item.line_total_cents
    assert_equal "new_sealed", item.condition
    assert_not_nil item.image_blob_signed_id
  end

  test "pickup orders have no shipping cost" do
    @cart.add(@gpu)

    order = place(shipping_method: "pickup").orders.first

    assert_equal 0, order.shipping_cents
    assert_equal 50_000, order.total_cents
  end

  test "free shipping listings cost nothing to ship" do
    free = publish(create_listing(title: "Free Shipping GPU", price_cents: 10_000, free_shipping: true))
    @cart.add(free)

    order = place.orders.first

    assert_equal 0, order.shipping_cents
  end

  # --- commission --------------------------------------------------------------------

  test "commission is zero while the flag is off" do
    set_setting("commission_enabled", false)
    set_setting("commission_percent", 5, value_type: "float")
    @cart.add(@gpu, quantity: 2)

    order = place.orders.first

    assert_equal 0, order.commission_cents
    assert_equal 0, order.commission_percent
  end

  test "commission is a rounded percent of the subtotal when enabled" do
    set_setting("commission_enabled", true)
    set_setting("commission_percent", 5, value_type: "float")
    @cart.add(@gpu, quantity: 1)
    @cart.add(publish(create_listing(title: "Odd Price RAM", price_cents: 1_111)))

    order = place.orders.first

    assert_equal BigDecimal("5"), order.commission_percent
    assert_equal (51_111 * 0.05).round, order.commission_cents
  end

  # --- stock -----------------------------------------------------------------------------

  test "decrements stock and keeps the listing published" do
    @cart.add(@gpu, quantity: 2)

    place

    @gpu.reload
    assert_equal 1, @gpu.quantity
    assert_predicate @gpu, :published?
  end

  test "buying the last units marks the listing sold and flags the item" do
    @cart.add(@gpu, quantity: 3)

    order = place.orders.first

    @gpu.reload
    assert_predicate @gpu, :sold?
    assert_predicate order.order_items.first, :sold_listing?
  end

  test "a listing that went unavailable aborts with an error and no orders" do
    @cart.add(@gpu, quantity: 2)
    @gpu.update_columns(status: "sold")

    result = place

    assert_not_predicate result, :success?
    assert_empty result.orders
    assert_equal 0, Order.count
    assert_includes result.errors.join(" "), @gpu.title
    assert_equal 1, @cart.cart_items.count
  end

  test "requesting more units than stock aborts" do
    @cart.add(@gpu, quantity: 2)
    @gpu.update_columns(quantity: 1)

    result = place

    assert_not_predicate result, :success?
    assert_empty result.orders
    assert_equal 0, Order.count
  end

  test "a price change since the cart was viewed aborts the placement" do
    @cart.add(@gpu, quantity: 2)
    @gpu.update_columns(price_cents: 45_000)

    result = place

    assert_not_predicate result, :success?
    assert_empty result.orders
    assert_equal 0, Order.count
  end

  test "a second checkout cannot sell the same last unit" do
    @cart.add(@gpu, quantity: 3)
    rival_cart = Cart.create!
    rival_cart.add(@gpu, quantity: 1)

    first = place
    second = place(cart: rival_cart)

    assert_predicate first, :success?
    assert_not_predicate second, :success?
    assert_equal 1, Order.count
    assert_equal 1, rival_cart.cart_items.count
  end

  # --- cart and inputs ---------------------------------------------------------------------

  test "clears the purchased items from the cart" do
    @cart.add(@gpu, quantity: 2)

    place

    assert_empty @cart.cart_items.reload
  end

  test "an empty cart aborts" do
    result = place

    assert_not_predicate result, :success?
    assert_empty result.orders
  end

  test "guest checkout stores the email without a buyer" do
    @cart.add(@gpu)

    order = place(buyer: nil, email: "guest@example.com").orders.first

    assert_nil order.buyer_id
    assert_equal "guest@example.com", order.buyer_email
  end

  test "an Address record is snapshotted into jsonb" do
    address = Address.create!(
      user: @buyer, country: countries(:es), first_name: "Mauro", last_name: "Lopez",
      street_line1: "Calle Mayor 1", postal_code: "28001", city: "Madrid", province: "28"
    )
    @cart.add(@gpu)

    order = place(shipping_address: address).orders.first

    assert_equal "Calle Mayor 1", order.shipping_address["street_line1"]
    assert_equal "28", order.shipping_address["province"]
    assert_equal "ES", order.shipping_address["country"]
  end

  test "invalid payment or shipping methods abort" do
    @cart.add(@gpu)

    result = place(payment_method: "bitcoin")
    assert_not_predicate result, :success?
    assert_equal 0, Order.count

    result = place(shipping_method: "drone")
    assert_not_predicate result, :success?
    assert_equal 0, Order.count
  end

  test "a missing email aborts guest checkouts" do
    @cart.add(@gpu)

    result = place(buyer: nil, email: nil)

    assert_not_predicate result, :success?
    assert_equal 0, Order.count
  end

  test "discount codes are accepted but not applied yet" do
    @cart.add(@gpu)

    order = place(discount_code: "LAUNCH10").orders.first

    assert_equal 0, order.discount_cents
    assert_equal 50_500, order.total_cents
  end

  private

  def place(cart: @cart, buyer: @buyer, email: nil, shipping_address: @address,
            shipping_method: "delivery", payment_method: "manual", discount_code: nil)
    Orders::Placer.call(
      cart: cart, buyer: buyer, email: email, shipping_address: shipping_address,
      shipping_method: shipping_method, payment_method: payment_method,
      discount_code: discount_code
    )
  end
end
