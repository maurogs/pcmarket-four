require "test_helper"

class CartTest < ActiveSupport::TestCase
  setup do
    @buyer = users(:pending)
    @cart = Cart.create!(user: @buyer)
    # @listing belongs to the confirmed user's store, so @buyer may buy it.
    @listing = publish(create_listing(price_cents: 50_000, quantity: 3, shipping_price_cents: 500))
  end

  # --- add --------------------------------------------------------------------

  test "add creates an item snapshotting the current price" do
    outcome = @cart.add(@listing, quantity: 2)

    assert_predicate outcome, :success?
    assert_equal :added, outcome.status
    assert_equal 2, outcome.item.quantity
    assert_equal 50_000, outcome.item.unit_price_cents
  end

  test "adding the same listing again increases the quantity" do
    @cart.add(@listing, quantity: 1)
    outcome = @cart.add(@listing, quantity: 2)

    assert_equal :increased, outcome.status
    assert_equal 1, @cart.cart_items.count
    assert_equal 3, @cart.cart_items.first.quantity
  end

  test "the total quantity is capped by the listing stock" do
    @cart.add(@listing, quantity: 2)
    outcome = @cart.add(@listing, quantity: 5)

    assert_predicate outcome, :success?
    assert_equal :capped, outcome.status
    assert_equal 3, outcome.item.quantity
  end

  test "a user cannot add their own listing" do
    own_cart = Cart.create!(user: users(:confirmed))

    outcome = own_cart.add(@listing)

    assert_equal :own_listing, outcome.status
    assert_not_predicate outcome, :success?
    assert_empty own_cart.cart_items
  end

  test "a guest cart can add any visible listing" do
    guest_cart = Cart.create!

    assert_predicate guest_cart.add(@listing), :success?
  end

  test "add rejects invisible listings and missing listings" do
    draft = create_listing(title: "Draft GPU")

    assert_equal :not_available, @cart.add(draft).status
    assert_equal :not_available, @cart.add(nil).status
    assert_empty @cart.cart_items
  end

  test "add treats a bogus quantity as one" do
    assert_equal 1, @cart.add(@listing, quantity: 0).item.quantity
    assert_equal 2, @cart.add(@listing, quantity: "abc").item.quantity
  end

  # --- totals -------------------------------------------------------------------

  test "count subtotal and shipping" do
    other = publish(create_listing(title: "AMD Radeon RX 6600 8GB", price_cents: 15_900,
                                   quantity: 5, shipping_price_cents: 300))
    buyer = Cart.create!
    buyer.add(@listing, quantity: 2)
    buyer.add(other, quantity: 1)

    assert_equal 3, buyer.count
    assert_equal 2 * 50_000 + 15_900, buyer.subtotal_cents
    # One fee per distinct listing, not per unit.
    assert_equal 800, buyer.shipping_cents
  end

  test "items_by_store groups by store ordered by name" do
    other_store = Store.create!(user: users(:pending), name: "Alpha Store", country: countries(:es))
    other = publish(create_listing(store: other_store, title: "Intel Core i5-12400 Processor",
                                   price_cents: 12_900))
    buyer = Cart.create!
    buyer.add(@listing)
    buyer.add(other)

    groups = buyer.items_by_store

    assert_equal 2, groups.size
    assert_equal [ "Alpha Store", "Confirmed Store" ], groups.map { |store, _| store.display_name }
    assert_equal [ other ], groups.first.last.map(&:listing)
  end

  # --- refresh! -----------------------------------------------------------------

  test "refresh drops items whose listing went invisible" do
    buyer = Cart.create!
    buyer.add(@listing)
    @listing.update_columns(status: "sold")

    notices = buyer.refresh!

    assert_empty buyer.cart_items.reload
    assert_equal 1, notices.size
    assert_includes notices.first, @listing.title
  end

  test "refresh syncs price changes and caps quantities to stock" do
    buyer = Cart.create!
    buyer.add(@listing, quantity: 3)

    @listing.update_columns(price_cents: 45_000, quantity: 2)
    notices = buyer.refresh!

    item = buyer.cart_items.first
    assert_equal 45_000, item.unit_price_cents
    assert_equal 2, item.quantity
    assert_equal 2, notices.size
  end

  test "refresh is silent while nothing changed" do
    buyer = Cart.create!
    buyer.add(@listing)

    assert_empty buyer.refresh!
  end

  # --- merge! -------------------------------------------------------------------

  test "merge moves the guest items and destroys the guest cart" do
    guest_cart = Cart.create!
    guest_cart.add(@listing, quantity: 2)

    @cart.merge!(guest_cart)

    assert_equal 1, @cart.cart_items.count
    assert_equal 2, @cart.cart_items.first.quantity
    assert_nil Cart.find_by(id: guest_cart.id)
  end

  test "merge re-runs the add rules so own and stale listings are dropped" do
    draft = create_listing(title: "Draft GPU")
    guest_cart = Cart.create!
    guest_cart.add(@listing, quantity: 1)
    guest_cart.add(draft)

    own_cart = Cart.create!(user: users(:confirmed))
    own_cart.merge!(guest_cart)

    # @listing belongs to users(:confirmed)'s store, so it is rejected as own_listing.
    assert_empty own_cart.cart_items.reload
    assert_nil Cart.find_by(id: guest_cart.id)
  end

  test "merge is a no-op for nil and for the same cart" do
    @cart.merge!(nil)
    @cart.merge!(@cart)

    assert @cart.persisted?
  end

  # --- token --------------------------------------------------------------------

  test "a token is generated on create and must be unique" do
    cart = Cart.create!

    assert_not_empty cart.token
    assert_raises(ActiveRecord::RecordInvalid) { Cart.create!(token: cart.token) }
  end
end
