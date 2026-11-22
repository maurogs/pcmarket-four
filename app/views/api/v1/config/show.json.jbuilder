json.data do
  json.site_name @site_name
  json.min_app_version @min_app_version
  json.default_locale I18n.default_locale.to_s
  json.locales @locales
  json.countries @countries do |country|
    json.code country.code
    json.name country.name
    json.currency country.currency
    json.default_locale country.default_locale
    json.regions country.regions.sort_by(&:name) do |region|
      json.id region.id
      json.name region.name
      json.code region.code
    end
  end
  json.feature_flags @features
  json.listing_conditions @conditions
  json.labels @labels
  json.tags @tags
  json.payment_methods @payment_methods.map { |method|
    {
      key: method,
      name: I18n.t("checkout.payment.methods.#{method}", default: method.humanize)
    }
  }
end
json.meta({})
