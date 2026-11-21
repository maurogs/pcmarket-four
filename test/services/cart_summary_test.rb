require "test_helper"

class CartSummaryTest < ActiveSupport::TestCase
  setup do
    @buyer = users(:buyer)
    @item = cart_items(:buyer_cart_gpu)
  end

  test "groups items by seller and sums shipping and subtotals" do
    other_listing = create_listing(user: create_seller("other-seller@example.com"), price_cents: 20_000)
    CartItem.create!(user: @buyer, listing: other_listing, quantity: 1)

    summary = CartSummary.for(user: @buyer)

    assert_equal 2, summary.groups.size
    assert_equal 2, summary.item_count
    assert_equal @item.listing.price_cents + 20_000, summary.subtotal_cents
    assert_equal 1_000, summary.shipping_cents
    assert_equal summary.subtotal_cents + 1_000, summary.total_cents
    assert summary.groups.all? { |group| group.items.size == 1 }
  end

  test "flags sold and unavailable items and excludes them from totals" do
    CartItem.create!(user: @buyer, listing: listings(:sold_listing), quantity: 1)

    summary = CartSummary.for(user: @buyer)
    sold_item = summary.items.find { |item| item.listing_id == listings(:sold_listing).id }

    assert_not sold_item.available?
    assert_equal "sold", sold_item.warning_code
    assert_equal @item.listing.price_cents, summary.subtotal_cents
    assert_equal [ { code: "sold", listing_id: listings(:sold_listing).id } ],
                 summary.warnings.map { |warning| { code: warning.code, listing_id: warning.listing_id } }
  end

  test "flags vacation mode" do
    stores(:seller_store).update!(vacation_mode: true)

    summary = CartSummary.for(user: @buyer)

    assert_equal "vacation", summary.items.first.warning_code
    assert_equal 0, summary.subtotal_cents
    assert_equal 0, summary.total_cents
  end

  test "clamps quantities above stock and warns" do
    listing = create_listing(user: users(:seller), quantity: 2, price_cents: 5_000)
    CartItem.create!(user: @buyer, listing: listing, quantity: 5)

    summary = CartSummary.for(user: @buyer)
    item = summary.items.find { |entry| entry.listing_id == listing.id }

    assert item.available?
    assert_equal 2, item.quantity
    assert_equal "quantity_reduced", item.warning_code
    assert_equal 10_000 + @item.listing.price_cents, summary.subtotal_cents
  end

  test "forces local pickup when an item has no shipping" do
    listing = create_listing(user: users(:seller), shipping_available: false, local_pickup: true,
                             shipping_price_cents: 0)
    CartItem.create!(user: @buyer, listing: listing, quantity: 1)

    summary = CartSummary.for(user: @buyer)

    assert summary.pickup_only?
    assert_equal 0, summary.shipping_cents
  end

  test "treats free shipping as zero" do
    @item.listing.update!(free_shipping: true, shipping_price_cents: 0)

    summary = CartSummary.for(user: @buyer)

    assert_equal 0, summary.shipping_cents
    assert summary.groups.first.free_shipping?
  end

  private

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
