countries = [
  {
    code: "ES", name_key: "countries.ES", enabled: true, vat_rate: 21.0,
    default_locale: "es", currency: "EUR"
  },
  {
    code: "FR", name_key: "countries.FR", enabled: false, vat_rate: 20.0,
    default_locale: "fr", currency: "EUR"
  },
  {
    code: "GB", name_key: "countries.GB", enabled: false, vat_rate: 20.0,
    default_locale: "en", currency: "GBP"
  },
  {
    code: "DE", name_key: "countries.DE", enabled: false, vat_rate: 19.0,
    default_locale: "de", currency: "EUR"
  },
  {
    code: "IT", name_key: "countries.IT", enabled: false, vat_rate: 22.0,
    default_locale: "it", currency: "EUR"
  },
  {
    code: "PT", name_key: "countries.PT", enabled: false, vat_rate: 23.0,
    default_locale: "pt", currency: "EUR"
  }
].freeze

countries.each do |attributes|
  country = Country.find_or_initialize_by(code: attributes[:code])
  country.assign_attributes(attributes)
  country.save!
end
