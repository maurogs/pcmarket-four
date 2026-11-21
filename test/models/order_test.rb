require "test_helper"

class OrderTest < ActiveSupport::TestCase
  setup do
    @order = orders(:pending_order)
    @order.order_items.create!(
      listing: listings(:published_gpu),
      title_snapshot: "NVIDIA GeForce RTX 4070 Super 12 GB",
      price_cents: 10_000,
      quantity: 2
    )
    @order.update!(shipping_cents: 500)
  end

  test "assigns a sequential PCM number on create" do
    order = Order.new(buyer: users(:buyer), seller: users(:seller), store: stores(:seller_store))

    assert order.save!
    assert_match(/\APCM-\d{4}-\d{6}\z/, order.number)
  end

  test "compute_totals! without commissions" do
    Setting.set("commissions_enabled", false)

    @order.compute_totals!

    assert_equal 20_000, @order.subtotal_cents
    assert_equal 0, @order.commission_cents
    assert_equal 0, @order.commission_percent
    assert_equal 20_500, @order.total_cents
    assert_equal 20_000, @order.net_to_seller_cents
  end

  test "compute_totals! with commissions enabled" do
    Setting.set("commissions_enabled", true)
    Setting.set("commission_percent", 5.0)

    @order.compute_totals!

    assert_equal 20_000, @order.subtotal_cents
    assert_equal 1_000, @order.commission_cents
    assert_equal BigDecimal("5.0"), @order.commission_percent
    assert_equal 20_500, @order.total_cents
    assert_equal 19_000, @order.net_to_seller_cents
  end
end
