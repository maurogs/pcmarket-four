require "test_helper"

class CartItemTest < ActiveSupport::TestCase
  setup do
    @cart = Cart.create!
    @listing = publish(create_listing(price_cents: 20_000, quantity: 5))
    @item = @cart.cart_items.create!(listing: @listing, quantity: 2, unit_price_cents: 20_000)
  end

  test "quantity must be a positive integer" do
    assert_raises(ActiveRecord::RecordInvalid) { @item.update!(quantity: 0) }
    assert_raises(ActiveRecord::RecordInvalid) { @item.update!(quantity: -1) }
    assert_raises(ActiveRecord::RecordInvalid) { @item.update!(quantity: nil) }
  end

  test "unit_price_cents cannot be negative" do
    assert_raises(ActiveRecord::RecordInvalid) { @item.update!(unit_price_cents: -1) }
  end

  test "a cart can hold a listing only once" do
    assert_raises(ActiveRecord::RecordInvalid) do
      @cart.cart_items.create!(listing: @listing, quantity: 1, unit_price_cents: 20_000)
    end
  end

  test "the same listing can sit in different carts" do
    other_cart = Cart.create!

    assert other_cart.cart_items.create!(listing: @listing, quantity: 1, unit_price_cents: 20_000)
  end

  test "total_cents multiplies quantity by the snapshot price" do
    assert_equal 40_000, @item.total_cents
  end

  test "price_changed? compares against the listing's current price" do
    assert_not_predicate @item, :price_changed?

    @listing.update_columns(price_cents: 18_000)
    assert_predicate @item.reload, :price_changed?
  end
end
