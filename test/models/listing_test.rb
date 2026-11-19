require "test_helper"

class ListingTest < ActiveSupport::TestCase
  setup do
    @listing = create_listing
  end

  # --- Basics ------------------------------------------------------------

  test "new listings are drafted with sensible defaults" do
    assert_predicate @listing, :draft?
    assert_predicate @listing, :new_sealed?
    assert_equal "gigabyte-rtx-4070-gaming-gpu-12-gb", @listing.slug
    assert_equal "EUR", @listing.currency
    assert_equal 1, @listing.quantity
    assert_equal "draft", @listing.status
  end

  test "required attributes" do
    listing = Listing.new(store: nil, category: nil, title: "", price_cents: nil, currency: "")

    assert_not listing.valid?
    %i[store category title price_cents currency].each do |attribute|
      assert listing.errors[attribute].any?
    end
  end

  test "title length bounds" do
    assert_not build_listing(title: "RTX").valid?
    assert_not build_listing(title: "x" * 121).valid?
  end

  test "price and quantity must be sane" do
    assert_not build_listing(price_cents: -1).valid?
    assert_not build_listing(price_cents: 10_000, quantity: 0).valid?
    assert_not build_listing(currency: "eu").valid?
  end

  test "original price must exceed price" do
    listing = build_listing(price_cents: 50_000, original_price_cents: 40_000)

    assert_not listing.valid?
    assert_equal [ I18n.t("errors.messages.must_exceed_price") ], listing.errors[:original_price_cents]
  end

  test "discount percent and display price" do
    listing = create_listing(price_cents: 50_000, original_price_cents: 60_000)

    assert_equal 17, listing.discount_percent
    usd = create_listing(price_cents: 50_000, currency: "USD")
    assert_equal "$500.00", I18n.with_locale(:en) { usd.display_price }
    assert_nil create_listing(price_cents: 50_000).discount_percent
  end

  # --- Specs ---------------------------------------------------------------

  test "specs are normalized to sorted string arrays" do
    listing = create_listing(specs: { "gpu_chipset" => %w[amd nvidia], "rgb_lighting" => true, "cpu_brand" => [] })

    assert_equal({ "gpu_chipset" => %w[amd nvidia], "rgb_lighting" => [ "true" ] }, listing.specs)
  end

  test "unknown filter keys and values are rejected" do
    listing = build_listing(specs: { "banana_mode" => [ "yes" ] })

    assert_not listing.valid?
    assert_equal [ I18n.t("errors.messages.unknown_filter_key", key: "banana_mode") ],
      listing.errors[:specs]

    listing = build_listing(specs: { "gpu_chipset" => %w[nvidia intel] })

    # "intel" is an inactive option, so it is not a valid value.
    assert_not listing.valid?
    assert_includes listing.errors[:specs],
      I18n.t("errors.messages.unknown_filter_value", key: "gpu_chipset", value: "intel")
  end

  test "boolean filters accept only true/false" do
    assert build_listing(specs: { "rgb_lighting" => false }).valid?
    assert_not build_listing(specs: { "rgb_lighting" => "maybe" }).valid?
  end

  test "with_specs ORs within a key and ANDs across keys" do
    nvidia = create_listing(specs: { "gpu_chipset" => [ "nvidia" ] })
    both = create_listing(title: "Sapphire RX 6600 Pulse", specs: { "gpu_chipset" => %w[nvidia amd] })
    amd_only = create_listing(title: "PowerColor Fighter RX", specs: { "gpu_chipset" => [ "amd" ] })
    combo = create_listing(specs: { "gpu_chipset" => [ "nvidia" ], "cpu_brand" => [ "amd" ] })

    or_ids = Listing.with_specs("gpu_chipset" => %w[nvidia amd]).ids
    assert_includes or_ids, nvidia.id
    assert_includes or_ids, both.id
    assert_includes or_ids, amd_only.id

    and_ids = Listing.with_specs("gpu_chipset" => [ "nvidia" ], "cpu_brand" => [ "amd" ]).ids

    assert_equal [ combo.id ], and_ids
  end

  test "spec_labels returns translated option labels" do
    listing = create_listing(specs: { "gpu_chipset" => [ "nvidia" ] })

    labels = I18n.with_locale(:es) { listing.spec_labels }

    assert_equal({ "gpu_chipset" => [ "NVIDIA" ] }, labels)
  end

  test "with_labels and with_seller_tags filter listings by slug" do
    deal = ProductLabel.create!(slug: "deal", color: "#dc2626", position: 99,
      name_translations: translations_for("Deal"))
    rgb = SellerTag.create!(slug: "rgb", position: 99, name_translations: translations_for("RGB"))
    tagged = create_listing
    create_listing
    tagged.product_labels << deal
    tagged.seller_tags << rgb

    assert_equal [ tagged.id ], Listing.with_labels(%w[deal]).ids
    assert_empty Listing.with_labels(%w[free_shipping])
    assert_equal [ tagged.id ], Listing.with_seller_tags(%w[rgb]).ids
    assert_empty Listing.with_seller_tags(%w[noctua])
  end

  # --- Images ---------------------------------------------------------------

  test "accepted image types are stored" do
    assert @listing.update(images: [ Rack::Test::UploadedFile.new(image_file, "image/png") ])
    assert_equal 1, @listing.reload.images.count
  end

  test "unsupported content types are rejected" do
    listing = create_listing
    listing.images = [ Rack::Test::UploadedFile.new(image_file("upload.txt"), "text/plain") ]

    assert_not listing.save
    assert_includes listing.errors[:images],
      I18n.t("errors.messages.unsupported_content_type", content_type: "text/plain")
  end

  test "image count limit comes from settings" do
    set_setting("max_images_per_listing", 1, value_type: "integer")
    listing = create_listing

    listing.images = [
      Rack::Test::UploadedFile.new(image_file, "image/png"),
      Rack::Test::UploadedFile.new(image_file("1x1.jpg"), "image/jpeg")
    ]

    assert_not listing.save
    assert_includes listing.errors[:images], I18n.t("errors.messages.too_many_images", max: 1)
  end

  # --- State machine --------------------------------------------------------

  test "happy path draft → pending_review → published stamps timestamps" do
    @listing.submit!

    assert_predicate @listing, :pending_review?
    assert_nil @listing.published_at

    @listing.approve!

    assert_predicate @listing, :published?
    assert_not_nil @listing.published_at
    assert_not_nil @listing.reviewed_at
  end

  test "reject and resubmit and archive" do
    @listing.submit!
    @listing.reject!

    assert_predicate @listing, :rejected?

    @listing.submit!
    assert_predicate @listing, :pending_review?

    @listing.archive!
    assert_predicate @listing, :archived?
  end

  test "pause and resume republish" do
    publish(@listing)
    @listing.pause!

    assert_predicate @listing, :paused?

    @listing.resume!

    assert_predicate @listing, :published?
  end

  test "mark_sold stamps sold_at" do
    publish(@listing)
    @listing.mark_sold!

    assert_predicate @listing, :sold?
    assert_not_nil @listing.sold_at
  end

  test "invalid transitions raise" do
    assert_raises(AASM::InvalidTransition) { @listing.approve! }
    publish(@listing)
    assert_raises(AASM::InvalidTransition) { @listing.submit! }
  end

  test "editing a published listing sends it back to review" do
    publish(@listing)

    @listing.update!(title: "MSI RTX 4070 Ventus OC Edition")

    assert_predicate @listing.reload, :pending_review?
  end

  test "attaching images to a published listing sends it back to review" do
    publish(@listing)

    @listing.update!(images: [ Rack::Test::UploadedFile.new(image_file, "image/png") ])

    assert_predicate @listing.reload, :pending_review?
  end

  test "with auto-approve enabled, edits stay published" do
    set_setting("listing_auto_approve", true)
    publish(@listing)

    @listing.update!(title: "Gigabyte RTX 4070 Eagle OC GPU")

    assert_predicate @listing.reload, :published?
  end

  test "non-reviewable edits keep the listing published" do
    publish(@listing)

    @listing.update!(views_count: @listing.views_count + 5)

    assert_predicate @listing.reload, :published?
  end

  test "status_label is localized" do
    publish(@listing)

    assert_equal "Publicado", I18n.with_locale(:es) { @listing.status_label }
    assert_equal "Published", I18n.with_locale(:en) { @listing.status_label }
  end

  # --- Misc -----------------------------------------------------------------

  test "province is validated only for Spanish listings" do
    listing = build_listing(country: countries(:es), province: "XX")

    assert_not listing.valid?
    assert listing.errors[:province].any?

    listing.update(country: countries(:fr), province: "XX")

    assert_predicate listing, :saved_changes?
    assert_equal "XX", listing.province
  end

  test "find_by_param finds by slug" do
    assert_equal @listing, Listing.find_by_param(@listing.slug)
    assert_nil Listing.find_by_param("no-such-listing")
  end

  private

  def translations_for(text)
    I18n.available_locales.to_h { |locale| [ locale.to_s, text ] }
  end
end
