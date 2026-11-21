class Setting < ApplicationRecord
  CACHE_PREFIX = "settings/v1"

  DEFAULTS = {
    "site_name" => "PCMarket",
    "listings_require_approval" => true,
    "commissions_enabled" => false,
    "commission_percent" => 5.0,
    "featured_listings_enabled" => false,
    "featured_price_cents" => 499,
    "sell_to_us_enabled" => false,
    "checkout_enabled" => true,
    "chat_enabled" => true,
    "registrations_enabled" => true,
    "maintenance_mode" => false,
    "max_images_per_listing" => 12,
    "max_active_listings_per_user" => 50,
    "saved_search_alerts_enabled" => true,
    "announcement_bar_text" => "",
    "reviews_enabled" => true,
    "payment_bank_transfer_enabled" => true,
    "bank_iban" => "ES00 0000 0000 0000 0000 0000",
    "bank_beneficiary" => "PCMarket S.L.",
    "payment_deadline_days" => 3,
    "stripe_enabled" => false,
    "inspection_window_days" => 2,
    "auto_complete_after_delivery_days" => 2,
    "auto_delivered_after_shipping_days" => 14,
    "seller_ship_deadline_days" => 3,
    "support_email" => "soporte@pcmarket.test",
    "blocked_words" => ""
  }.freeze

  enum :value_type, { boolean: "boolean", integer: "integer", string: "string", decimal: "decimal" }

  validates :key, presence: true, uniqueness: true
  validates :value_type, presence: true

  after_save :expire_cache
  after_destroy :expire_cache

  class << self
    def get(key, default = nil)
      key = key.to_s
      value = cached_values.fetch(key) { DEFAULTS[key] }
      value.nil? ? default : value
    end

    # One query (and one cache entry) for the whole settings table. The table
    # is tiny and read on every request, so per-key lookups would multiply
    # queries unnecessarily.
    def cached_values
      Rails.cache.fetch("#{CACHE_PREFIX}/all") do
        all.to_h { |record| [ record.key, record.typed_value ] }
      end
    end

    def enabled?(key)
      ActiveModel::Type::Boolean.new.cast(get(key)) == true
    end

    def set(key, value)
      record = find_or_initialize_by(key: key.to_s)
      record.value_type = infer_value_type(value) if record.new_record?
      record.value = serialise(value)
      record.save!
      value
    end

    def ensure_defaults!
      DEFAULTS.each do |key, value|
        record = find_or_initialize_by(key: key)
        next if record.persisted?

        record.value_type = infer_value_type(value)
        record.value = serialise(value)
        record.save!
      end
    end

    def cache_key(key)
      "#{CACHE_PREFIX}/#{key}"
    end

    def infer_value_type(value)
      case value
      when true, false then "boolean"
      when Integer then "integer"
      when BigDecimal, Float then "decimal"
      else "string"
      end
    end

    def serialise(value)
      case value
      when BigDecimal then value.to_s("F")
      else value.to_s
      end
    end
  end

  def typed_value
    case value_type
    when "boolean" then ActiveModel::Type::Boolean.new.cast(value)
    when "integer" then value.to_i
    when "decimal" then value.to_d
    else value
    end
  end

  private

  def expire_cache
    Rails.cache.delete(self.class.cache_key(key))
    Rails.cache.delete("#{CACHE_PREFIX}/all")
  end
end
