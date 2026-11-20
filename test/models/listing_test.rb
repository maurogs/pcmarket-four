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

  test ".sanitize_specs keeps only the category's form fields and known values" do
    raw = ActionController::Parameters.new(
      "gpu_chipset" => [ "nvidia", "banana" ], "rgb_lighting" => "1",
      "cpu_brand" => [ "arm" ], "console_platform" => [ "steam_deck" ]
    ).permit!

    clean = Listing.sanitize_specs(categories(:gpus), raw)

    # "banana"/"arm" are unknown options and console_platform is not attached
    # to the gpus subtree — all dropped; the checkbox "1" becomes "true".
    assert_equal({ "gpu_chipset" => [ "nvidia" ], "rgb_lighting" => [ "true" ] }, clean)
  end

  test "required specs are enforced on submit but not on drafts" do
    memory = FilterDefinition.create!(key: "gpu_memory", input_type: :single_select,
                                      required_in_form: true, position: 4,
                                      label_translations: { "en": "Memory" },
                                      group_translations: { "en": "Graphics" })
    memory.filter_options.create!(value: "8gb", label_translations: { "en": "8 GB" })
    CategoryFilter.create!(category: categories(:gpus), filter_definition: memory)

    # Drafts may be incomplete — saving without the required spec is fine.
    listing = create_listing(specs: { "gpu_chipset" => [ "nvidia" ] })
    assert_predicate listing, :draft?

    assert_raises(ActiveRecord::RecordInvalid) { listing.submit! }
    assert_includes listing.errors[:specs],
      I18n.t("errors.messages.missing_required_spec", label: "Memory")

    listing.update!(specs: { "gpu_chipset" => [ "nvidia" ], "gpu_memory" => [ "8gb" ] })
    attach_photo(listing)
    listing.submit!
    assert_predicate listing, :pending_review?
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

  test "ordered_images follows image_order" do
    @listing.update!(images: [ Rack::Test::UploadedFile.new(image_file("1x1.jpg"), "image/jpeg"),
                               Rack::Test::UploadedFile.new(image_file, "image/png") ])
    first, second = @listing.images.to_a

    @listing.update!(image_order: [ second.id, first.id ].map(&:to_s).to_json)

    assert_equal [ second.id, first.id ], @listing.reload.ordered_images.map(&:id)
  end

  test "ordered_images appends images missing from image_order at the end" do
    @listing.update!(images: [ Rack::Test::UploadedFile.new(image_file("1x1.jpg"), "image/jpeg"),
                               Rack::Test::UploadedFile.new(image_file, "image/png") ])
    first, second = @listing.images.to_a

    # Only the second image is ordered (plus a stale id that no longer exists).
    @listing.update!(image_order: [ second.id, 999_999_999 ].map(&:to_s).to_json)

    assert_equal [ second.id, first.id ], @listing.reload.ordered_images.map(&:id)
  end

  test "remove_image_ids purges only the matching attachment" do
    @listing.update!(images: [ Rack::Test::UploadedFile.new(image_file("1x1.jpg"), "image/jpeg"),
                               Rack::Test::UploadedFile.new(image_file, "image/png") ])
    first, second = @listing.images.to_a

    @listing.update!(remove_image_ids: [ first.id ])

    assert_equal [ second.id ], @listing.reload.images.map(&:id)
  end

  test "removing an image from a published listing returns it to pending review" do
    publish(@listing)
    @listing.update!(images: [ Rack::Test::UploadedFile.new(image_file("1x1.jpg"), "image/jpeg"),
                               Rack::Test::UploadedFile.new(image_file, "image/png") ])
    assert_predicate @listing.reload, :pending_review?

    @listing.approve!
    @listing.update!(remove_image_ids: [ @listing.images.first.id ])

    assert_predicate @listing.reload, :pending_review?
    # publish() attached a stub photo, so the gallery is 3 → removing one leaves 2.
    assert_equal 2, @listing.images.count
  end

  test "with auto-approve enabled, image changes keep the listing published" do
    set_setting("listing_auto_approve", true)
    publish(@listing)

    @listing.update!(images: [ Rack::Test::UploadedFile.new(image_file, "image/png") ])

    assert_predicate @listing.reload, :published?
  end

  # --- State machine --------------------------------------------------------

  test "happy path draft → pending_review → published stamps timestamps" do
    attach_photo(@listing)
    @listing.submit!

    assert_predicate @listing, :pending_review?
    assert_nil @listing.published_at

    @listing.approve!

    assert_predicate @listing, :published?
    assert_not_nil @listing.published_at
    assert_not_nil @listing.reviewed_at
  end

  test "reject and resubmit and archive" do
    attach_photo(@listing)
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

  test "a paused listing can be marked as sold" do
    publish(@listing)
    @listing.pause!
    @listing.mark_sold!

    assert_predicate @listing, :sold?
    assert_not_nil @listing.sold_at
  end

  test "submitting without photos is refused with the image error" do
    assert_raises(ActiveRecord::RecordInvalid) { @listing.submit! }
    assert_includes @listing.errors[:base],
      I18n.t("errors.messages.image_required_for_review")

    attach_photo(@listing)
    @listing.submit!
    assert_predicate @listing, :pending_review?
  end

  # --- record_offline_sale! ---------------------------------------------------

  test "record_offline_sale! sells the last unit and stamps sold_at" do
    publish(@listing)

    assert @listing.record_offline_sale!

    assert_predicate @listing, :sold?
    assert_not_nil @listing.sold_at
  end

  test "record_offline_sale! only decrements when stock is left" do
    publish(@listing)
    @listing.update!(quantity: 3)

    assert_not @listing.record_offline_sale!

    @listing.reload
    assert_equal 2, @listing.quantity
    assert_predicate @listing, :published?
    assert_nil @listing.sold_at
  end

  test "record_offline_sale! works on a paused listing" do
    publish(@listing)
    @listing.pause!

    assert @listing.record_offline_sale!

    assert_predicate @listing, :sold?
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
