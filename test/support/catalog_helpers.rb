# Factories shared across catalog tests (see test/test_helper.rb).
module CatalogHelpers
  # Attaches a stub photo (submitting for review requires one, see
  # Listing#image_present_for_review).
  def attach_photo(listing)
    listing.images.attach(io: File.open(image_file), filename: "photo.png", content_type: "image/png")
  end

  # Publishes a listing the way the state machine would, with timestamps.
  # Attaches a stub photo first: submitting for review requires one (see
  # Listing#image_present_for_review).
  def publish(listing, published_at: Time.current)
    attach_photo(listing) unless listing.images.attached?
    listing.submit!
    listing.approve!
    listing.update_columns(published_at: published_at)
    listing.reload
  end

  def build_listing(**overrides)
    defaults = {
      store: stores(:confirmed_store),
      category: categories(:gpus),
      title: "Gigabyte RTX 4070 Gaming GPU 12 GB",
      price_cents: 50_000,
      currency: "EUR",
      condition: :new_sealed,
      shipping_method: :own_label
    }
    Listing.new(defaults.merge(overrides))
  end

  def create_listing(**overrides)
    listing = build_listing(**overrides)
    listing.save!
    listing
  end

  # A published store review (author defaults to a non-owner user). Review
  # callbacks don't fire under transactional fixtures, so call
  # Stores::RatingRecalculator when the denormalized counters matter.
  def create_review(store: stores(:confirmed_store), author: users(:pending), **overrides)
    Review.create!({ store: store, author: author, rating: 5,
                     title: "Great seller", body: "Fast shipping, item as described." }
                     .merge(overrides))
  end

  # A small browse catalog (two published GPUs in different price bands, a
  # hidden GPU, a CPU in another subtree) shared by the Phase 1b browse tests.
  # Built per test instead of fixtures so global-scope tests elsewhere keep
  # asserting against their own data only.
  def create_browse_catalog
    gpu_rtx = publish(create_listing(
      title: "NVIDIA GeForce RTX 3060 12GB", price_cents: 24_900, original_price_cents: 32_900,
      condition: :used_like_new, free_shipping: true, allow_offers: true, ships_within_days: 2,
      province: "madrid", city: "Madrid", highlights: [ "Original box", "Invoice included" ],
      specs: { "gpu_chipset" => [ "nvidia" ] }
    ), published_at: 3.days.ago)
    gpu_rx = publish(create_listing(
      title: "AMD Radeon RX 6600 8GB", price_cents: 15_900, condition: :used_good,
      specs: { "gpu_chipset" => [ "amd" ] }
    ), published_at: 2.days.ago)
    gpu_hidden = create_listing(title: "Pending Graphics Card Should Not Show", price_cents: 44_900)
    attach_photo(gpu_hidden)
    gpu_hidden.submit!
    cpu_i5 = publish(create_listing(
      title: "Intel Core i5-12400 Processor", category: categories(:cpus), price_cents: 12_900,
      specs: { "cpu_brand" => [ "intel" ] }
    ), published_at: 1.day.ago)

    { gpu_rtx: gpu_rtx, gpu_rx: gpu_rx, gpu_pending: gpu_hidden, cpu_i5: cpu_i5 }
  end

  # Boolean setting toggle that also resets the AppSettings cache.
  def set_setting(key, value, value_type: "boolean")
    setting = Setting.find_or_initialize_by(key: key.to_s)
    setting.update!(value: value, value_type: value_type)
    Rails.cache.delete("app_settings/#{key}")
    setting
  end

  def image_file(name = "1x1.png")
    Rails.root.join("test/fixtures/files/#{name}").to_s
  end
end
