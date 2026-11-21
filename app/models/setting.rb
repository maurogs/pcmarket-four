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
    "blocked_words" => "",
    "allow_non_eur_countries" => false,
    "company_legal_name" => "PCMarket Marketplace S.L.",
    "company_tax_id" => "B00000000",
    "company_address" => "Calle Ejemplo 1, 28001 Madrid, España",
    "company_registry" => "Registro Mercantil de Madrid, Tomo 0000, Folio 0, Hoja M-000000",
    "contact_email" => "hola@pcmarket.test",
    "dpo_email" => "privacidad@pcmarket.test",
    "legal_email" => "legal@pcmarket.test",
    "support_phone" => "+34 900 000 000",
    "support_hours" => "L-V 9:00-18:00 CET"
  }.freeze

  GROUPS = {
    "general" => %w[site_name maintenance_mode allow_non_eur_countries],
    "marketplace" => %w[listings_require_approval checkout_enabled chat_enabled
                        registrations_enabled reviews_enabled saved_search_alerts_enabled],
    "monetisation" => %w[commissions_enabled commission_percent featured_listings_enabled
                         featured_price_cents sell_to_us_enabled],
    "payments" => %w[payment_bank_transfer_enabled bank_iban bank_beneficiary
                     payment_deadline_days stripe_enabled],
    "orders" => %w[inspection_window_days auto_complete_after_delivery_days
                   auto_delivered_after_shipping_days seller_ship_deadline_days],
    "limits" => %w[max_images_per_listing max_active_listings_per_user],
    "content" => %w[announcement_bar_text blocked_words],
    "company" => %w[company_legal_name company_tax_id company_address company_registry
                    contact_email dpo_email legal_email support_phone support_hours],
    "communication" => %w[support_email]
  }.freeze

  FEATURE_FLAGS = %w[
    commissions_enabled featured_listings_enabled sell_to_us_enabled checkout_enabled
    chat_enabled registrations_enabled maintenance_mode reviews_enabled
    saved_search_alerts_enabled stripe_enabled payment_bank_transfer_enabled
    listings_require_approval
  ].freeze

  LIMITS = {
    "commission_percent" => { min: 0, max: 100 },
    "featured_price_cents" => { min: 0, max: 100_000 },
    "max_images_per_listing" => { min: 1, max: 30 },
    "max_active_listings_per_user" => { min: 1, max: 10_000 },
    "payment_deadline_days" => { min: 1, max: 60 },
    "inspection_window_days" => { min: 1, max: 60 },
    "auto_complete_after_delivery_days" => { min: 1, max: 90 },
    "auto_delivered_after_shipping_days" => { min: 1, max: 180 },
    "seller_ship_deadline_days" => { min: 1, max: 60 }
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
        record.group = group_for(key)
        record.feature_flag = FEATURE_FLAGS.include?(key)
        record.save!
      end
    end

    def group_for(key)
      GROUPS.find { |_group, keys| keys.include?(key.to_s) }&.first || "general"
    end

    def type_for(key)
      infer_value_type(DEFAULTS[key.to_s]).to_s
    end

    def feature_flag?(key)
      FEATURE_FLAGS.include?(key.to_s)
    end

    def limits_for(key)
      LIMITS[key.to_s]
    end

    def cast(key, raw)
      case type_for(key)
      when "boolean" then ActiveModel::Type::Boolean.new.cast(raw) == true
      when "integer" then raw.to_s.gsub(/[^0-9-]/, "").to_i
      when "decimal" then raw.to_s.tr(",", ".").to_d
      else raw.to_s
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
