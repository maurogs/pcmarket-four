# This file seeds the development and test databases. Everything here is
# idempotent: running it twice does not duplicate or overwrite data.

COUNTRIES = [
  { code: "ES", name_key: "countries.es", currency: "EUR", default_locale: "es",
    enabled: true, launched_at: Time.zone.parse("2026-01-15"), vat_rate: 21 },
  { code: "FR", name_key: "countries.fr", currency: "EUR", default_locale: "fr",
    enabled: false, vat_rate: 20 },
  { code: "GB", name_key: "countries.gb", currency: "GBP", default_locale: "en",
    enabled: false, vat_rate: 20 },
  { code: "DE", name_key: "countries.de", currency: "EUR", default_locale: "de",
    enabled: false, vat_rate: 19 },
  { code: "IT", name_key: "countries.it", currency: "EUR", default_locale: "it",
    enabled: false, vat_rate: 22 },
  { code: "PT", name_key: "countries.pt", currency: "EUR", default_locale: "pt",
    enabled: false, vat_rate: 23 }
].freeze

SETTINGS = [
  { key: "sell_to_us_enabled", value: false, value_type: "boolean", group: "sales",
    description_key: "settings.descriptions.sell_to_us_enabled" },
  { key: "payments_enabled", value: false, value_type: "boolean", group: "sales",
    description_key: "settings.descriptions.payments_enabled" },
  { key: "commission_enabled", value: false, value_type: "boolean", group: "sales",
    description_key: "settings.descriptions.commission_enabled" },
  { key: "commission_percent", value: 0, value_type: "float", group: "sales",
    description_key: "settings.descriptions.commission_percent" },
  { key: "featured_listings_enabled", value: false, value_type: "boolean", group: "listings",
    description_key: "settings.descriptions.featured_listings_enabled" },
  { key: "offers_enabled", value: true, value_type: "boolean", group: "listings",
    description_key: "settings.descriptions.offers_enabled" },
  { key: "chat_enabled", value: true, value_type: "boolean", group: "community",
    description_key: "settings.descriptions.chat_enabled" },
  { key: "checkout_enabled", value: true, value_type: "boolean", group: "sales",
    description_key: "settings.descriptions.checkout_enabled" },
  { key: "guest_checkout_enabled", value: true, value_type: "boolean", group: "sales",
    description_key: "settings.descriptions.guest_checkout_enabled" },
  { key: "registrations_enabled", value: true, value_type: "boolean", group: "account",
    description_key: "settings.descriptions.registrations_enabled" },
  { key: "maintenance_mode", value: false, value_type: "boolean", group: "general",
    description_key: "settings.descriptions.maintenance_mode" },
  { key: "announcement_bar_enabled", value: true, value_type: "boolean", group: "general",
    description_key: "settings.descriptions.announcement_bar_enabled" },
  { key: "announcement_bar_text", value_type: "json", group: "general",
    description_key: "settings.descriptions.announcement_bar_text",
    value: {
      "en" => "Free shipping on your first order — launch special 🚀",
      "es" => "Envío gratis en tu primer pedido — especial de lanzamiento 🚀",
      "fr" => "Livraison offerte sur votre première commande — spécial lancement 🚀",
      "de" => "Kostenloser Versand für Ihre erste Bestellung — Launch-Special 🚀",
      "it" => "Spedizione gratuita sul primo ordine — speciale lancio 🚀",
      "pt" => "Envio grátis na sua primeira encomenda — especial de lançamento 🚀"
    } },
  { key: "site_name", value: "PCMarket", value_type: "string", group: "general",
    description_key: "settings.descriptions.site_name" },
  { key: "support_email", value: "support@pcmarket.example", value_type: "string", group: "general",
    description_key: "settings.descriptions.support_email" },
  { key: "listing_auto_approve", value: false, value_type: "boolean", group: "listings",
    description_key: "settings.descriptions.listing_auto_approve" },
  { key: "max_images_per_listing", value: 12, value_type: "integer", group: "listings",
    description_key: "settings.descriptions.max_images_per_listing" },
  { key: "saved_search_alerts_enabled", value: true, value_type: "boolean", group: "community",
    description_key: "settings.descriptions.saved_search_alerts_enabled" }
].freeze

def seed_record(model, attributes)
  record = model.find_or_initialize_by(attributes.slice(:key, :code))
  return record if record.persisted?

  record.update!(attributes)
  record
end

COUNTRIES.each { |attrs| seed_record(Country, attrs) }
SETTINGS.each { |attrs| seed_record(Setting, attrs) }

# Sample data for local development (never in production, never duplicated).
if Rails.env.development? && Country.enabled.any? && ENV.fetch("SEED_SAMPLE", "1") != "0"
  Country.enabled.each do |country|
    Faker::Config.locale = country.default_locale
    5.times do |i|
      User.find_or_create_by!(email: "seller#{i + 1}@#{country.code.downcase}.example.com") do |u|
        u.username = User.generate_username(Faker::Internet.username)
        u.first_name = Faker::Name.first_name
        u.last_name = Faker::Name.last_name
        u.phone = Faker::PhoneNumber.phone_number
        u.country = country
        u.locale = country.default_locale
        u.password = Devise.friendly_token(20)
        u.skip_confirmation!
      end
    end
  end
  Rails.logger.info "Seeded #{User.count} sample users (development only)."
end

puts "Seeded #{Country.count} countries and #{Setting.count} settings."
