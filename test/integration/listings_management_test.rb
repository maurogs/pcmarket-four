require "test_helper"

class ListingsManagementTest < ActionDispatch::IntegrationTest
  setup do
    @seller = users(:seller)
    @buyer = users(:buyer)
    @category = categories(:graphics_cards)
    @published = listings(:published_gpu)
    @image = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/gpu.jpg"), "image/jpeg")
  end

  test "create draft without images" do
    sign_in @seller

    assert_difference -> { Listing.count }, 1 do
      post listings_path, params: { listing: attributes, commit: "draft" }
    end

    listing = Listing.order(:created_at).last
    assert_redirected_to seller_listings_path(locale: :es)
    assert listing.draft?
    assert_equal 129_950, listing.price_cents
    assert_equal 149_950, listing.original_price_cents
    assert_equal 1, listing.quantity
    assert_empty listing.images.attachments
  end

  test "submitting requires at least one image" do
    sign_in @seller

    assert_no_difference -> { Listing.count } do
      post listings_path, params: { listing: attributes, commit: "submit" }
    end

    assert_response :unprocessable_entity
    assert_select ".text-rose-900", text: /imagen/i
  end

  test "submitting with approval enabled moves the listing to pending review" do
    Setting.set("listings_require_approval", true)
    sign_in @seller

    post listings_path, params: { listing: attributes(images: [ @image ]), commit: "submit" }

    listing = Listing.order(:created_at).last
    assert_redirected_to seller_listings_path(locale: :es)
    assert listing.pending_review?
    assert listing.images.attached?
  end

  test "submitting with approval disabled publishes the listing" do
    Setting.set("listings_require_approval", false)
    sign_in @seller

    post listings_path, params: { listing: attributes(images: [ @image ]), commit: "submit" }

    assert Listing.order(:created_at).last.published?
  end

  test "price parsing accepts Spanish and plain decimal formats" do
    sign_in @seller

    post listings_path, params: { listing: attributes(price: "1.299,50"), commit: "draft" }
    assert_equal 129_950, Listing.order(:created_at).last.price_cents

    post listings_path, params: { listing: attributes(price: "1299.50"), commit: "draft" }
    assert_equal 129_950, Listing.order(:created_at).last.price_cents

    post listings_path, params: { listing: attributes(price: "1300"), commit: "draft" }
    assert_equal 130_000, Listing.order(:created_at).last.price_cents
  end

  test "specs only keep effective category filter keys" do
    sign_in @seller

    post listings_path, params: {
      listing: attributes(specs: { cpu_brand: "intel", vram: "24", not_a_filter: "x" }),
      commit: "draft"
    }

    specs = Listing.order(:created_at).last.specs
    assert_equal "intel", specs["cpu_brand"]
    assert_not specs.key?("vram")
    assert_not specs.key?("not_a_filter")
  end

  test "category frame reload renders only the specs frame" do
    sign_in @seller

    get new_listing_path, params: { category_id: @category.id },
        headers: { "Turbo-Frame" => "listing_specs" }

    assert_response :success
    assert_select "turbo-frame#listing_specs", 1
    assert_select "input[name='listing[specs][cpu_brand]'], select[name='listing[specs][cpu_brand]']"
    assert_select "header", count: 0
    assert_select "input[name='listing[category_id]'][value='#{@category.id}']"
  end

  test "editing a published title sends it back to review" do
    sign_in @seller

    patch listing_path(@published, locale: :es), params: {
      listing: { title: "NVIDIA RTX 4070 Super 12 GB revisada" }, commit: "draft"
    }

    assert_redirected_to seller_listings_path(locale: :es)
    assert @published.reload.pending_review?
  end

  test "editing a published price keeps it published" do
    sign_in @seller

    patch listing_path(@published, locale: :es), params: { listing: { price: "500,00" }, commit: "draft" }

    assert @published.reload.published?
    assert_equal 50_000, @published.price_cents
  end

  test "quota limits active listings" do
    Setting.set("max_active_listings_per_user", 1)
    sign_in @buyer

    post listings_path, params: { listing: attributes, commit: "draft" }
    assert_redirected_to seller_listings_path(locale: :es)

    assert_no_difference -> { Listing.count } do
      post listings_path, params: { listing: attributes, commit: "draft" }
    end
    assert_response :unprocessable_entity
    assert_select ".text-rose-900", text: /límite/i
  end

  test "non owners cannot edit a listing" do
    sign_in @buyer

    get edit_listing_path(@published, locale: :es)

    assert_redirected_to root_path
    assert_equal I18n.t("errors.not_authorized"), flash[:alert]
  end

  test "pause resume and sold transitions" do
    sign_in @seller

    post listing_pause_path(@published, locale: :es)
    assert @published.reload.paused?

    delete listing_pause_path(@published, locale: :es)
    assert @published.reload.published?

    post listing_sale_path(@published, locale: :es)
    assert @published.reload.sold?
  end

  test "duplicating a listing creates a draft copy" do
    sign_in @seller

    assert_difference -> { Listing.count }, 1 do
      post seller_listing_duplication_path(@published, locale: :es)
    end

    copy = Listing.order(:created_at).last
    assert copy.draft?
    assert_equal @published.title, copy.title
    assert_redirected_to edit_listing_path(copy, locale: :es)
  end

  test "bulk pause only touches owned listings" do
    sign_in @seller
    draft = listings(:draft_gpu)

    post seller_bulk_listing_actions_path,
         params: { listing_ids: [ @published.id, draft.id ], bulk_action: "pause" }

    assert_redirected_to seller_listings_path(locale: :es)
    assert @published.reload.paused?
    assert draft.reload.draft?
  end

  test "the first listing creates an individual store" do
    assert_nil @buyer.store
    sign_in @buyer

    post listings_path, params: { listing: attributes, commit: "draft" }

    store = @buyer.reload.store
    assert store.present?
    assert store.individual?
    assert_equal @buyer.username, store.name
  end

  private

  def attributes(overrides = {})
    {
      category_id: @category.id,
      title: "NVIDIA RTX 4090 Founders Edition",
      brand: "NVIDIA",
      model_name_text: "RTX 4090",
      condition: "used_like_new",
      quantity: 1,
      description: "Tarjeta gráfica en perfecto estado con caja original y todos los accesorios.",
      price: "1.299,50",
      original_price: "1499.50",
      accepts_offers: "1",
      shipping_available: "1",
      free_shipping: "0",
      shipping_price: "5.95",
      ships_within_days: "3",
      local_pickup: "0",
      region_id: regions(:madrid).id,
      city: "Madrid",
      postal_code: "28001",
      tags: %w[rgb compact],
      specs: { cpu_brand: "intel" }
    }.merge(overrides)
  end
end
