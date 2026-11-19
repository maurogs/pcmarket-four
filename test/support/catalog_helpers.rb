# Factories shared across catalog tests (see test/test_helper.rb).
module CatalogHelpers
  # Publishes a listing the way the state machine would, with timestamps.
  def publish(listing, published_at: Time.current)
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
