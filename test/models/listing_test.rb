require "test_helper"

class ListingTest < ActiveSupport::TestCase
  def build_listing(attributes = {})
    Listing.new({
      user: users(:seller),
      category: categories(:graphics_cards),
      title: "NVIDIA GeForce RTX 4080 Super",
      description: "Tarjeta gráfica en perfecto estado con caja original y garantía.",
      price_cents: 99_900,
      condition: :used_like_new,
      country_code: "ES"
    }.merge(attributes))
  end

  test "valid listing" do
    assert build_listing.valid?
  end

  test "requires a title between 10 and 120 characters" do
    assert_not build_listing(title: "Short").valid?
    assert_not build_listing(title: "a" * 121).valid?
  end

  test "requires a description of at least 30 characters" do
    listing = build_listing(description: "Too short")

    assert_not listing.valid?
    assert listing.errors[:description].any?
  end

  test "requires a positive price" do
    assert_not build_listing(price_cents: 0).valid?
    assert_not build_listing(price_cents: -1).valid?
    assert_not build_listing(price_cents: 100_000_001).valid?
  end

  test "original price must be greater than the selling price" do
    listing = build_listing(original_price_cents: 99_900)
    assert_not listing.valid?
    assert listing.errors[:original_price_cents].any?
  end

  test "rejects listings in disabled countries" do
    listing = build_listing(country_code: "FR")
    assert_not listing.valid?
    assert listing.errors[:country_code].any?
  end

  test "rejects categories that are not leaves" do
    listing = build_listing(category: categories(:components))
    assert_not listing.valid?
    assert listing.errors[:category].any?
  end

  test "submit_for_review! moves to pending review when approval is required" do
    Setting.set("listings_require_approval", true)
    listing = listings(:draft_listing_approval)

    assert listing.submit_for_review!
    assert listing.pending_review?
    assert_nil listing.published_at
  end

  test "submit_for_review! publishes directly when approval is disabled" do
    Setting.set("listings_require_approval", false)
    listing = listings(:draft_listing_auto)

    assert listing.submit_for_review!
    assert listing.published?
    assert_not_nil listing.published_at
  end

  test "approve! publishes a pending listing and records the reviewer" do
    listing = listings(:draft_listing_approval)
    listing.update!(status: :pending_review)

    assert listing.approve!(users(:moderator))
    assert listing.published?
    assert_equal users(:moderator).id, listing.reviewed_by_id
    assert_not_nil listing.reviewed_at
  end

  test "reject! records the reviewer and reason" do
    listing = listings(:draft_listing_approval)
    listing.update!(status: :pending_review)

    assert listing.reject!(users(:moderator), "Faltan fotografías")
    assert listing.rejected?
    assert_equal "Faltan fotografías", listing.rejection_reason
    assert_equal users(:moderator).id, listing.reviewed_by_id
  end

  test "pause, resume and mark_sold follow the lifecycle" do
    listing = listings(:published_gpu)

    assert listing.pause!
    assert listing.paused?
    assert listing.resume!
    assert listing.published?
    assert listing.mark_sold!
    assert listing.sold?
  end

  test "visible scope only includes publishable listings" do
    visible = Listing.visible.to_a

    assert_includes visible, listings(:published_gpu)
    assert_not_includes visible, listings(:draft_gpu)
    assert_not_includes visible, listings(:suspended_owner_listing)
    assert_not_includes visible, listings(:zero_quantity_listing)
    assert_not_includes visible, listings(:disabled_country_listing)
  end

  test "featured scope uses featured_until" do
    assert_includes Listing.featured, listings(:published_gpu)
    assert_not_includes Listing.featured, listings(:draft_gpu)
  end

  test "in_category includes listings from descendant categories" do
    assert_includes Listing.in_category(categories(:components)), listings(:published_gpu)
    assert_not_includes Listing.in_category(categories(:laptops)), listings(:published_gpu)
  end

  test "search_text finds listings by title, ignoring accents" do
    assert_includes Listing.search_text("RTX").to_a, listings(:published_gpu)
    assert_includes Listing.search_text("grafica").to_a, listings(:published_gpu)
  end
end
