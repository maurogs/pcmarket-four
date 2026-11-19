# Country rows (see also app/models/country.rb for validations).
countries = [
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

countries.each { |attrs| seed_record(Country, attrs, %i[code]) }
