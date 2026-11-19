require "test_helper"

class CountryTest < ActiveSupport::TestCase
  setup { I18n.locale = :en }

  test "countries are addressed by ISO code" do
    assert_equal "ES", countries(:es).to_param
  end

  test "only known codes and locales are allowed" do
    country = Country.new(code: "US", name_key: "countries.es", currency: "USD",
                          default_locale: "zz", vat_rate: 0)
    assert_not country.valid?
    assert_includes country.errors[:code], "is not included in the list"
    assert_includes country.errors[:default_locale], "is not included in the list"
  end

  test "enabled countries need a launch date" do
    country = Country.new(code: "IT", name_key: "countries.it", currency: "EUR",
                          default_locale: "it", vat_rate: 22, enabled: true)
    assert_not country.valid?
    assert_includes country.errors[:launched_at], "can't be blank"
  end

  test "currency must be a three letter code" do
    country = Country.new(code: "PT", name_key: "countries.pt", currency: "euros",
                          default_locale: "pt", vat_rate: 23)
    assert_not country.valid?
    assert_includes country.errors[:currency], "is invalid"
  end

  test "enabled scope returns only enabled markets" do
    assert_equal [ countries(:es) ], Country.enabled.to_a
  end

  test "name falls back to the code for unknown keys" do
    country = Country.new(code: "DE", name_key: "countries.de", currency: "EUR",
                          default_locale: "de", vat_rate: 19)
    assert_equal "Germany", I18n.with_locale(:en) { country.name }
    assert_equal "Deutschland", I18n.with_locale(:de) { country.name }
  end
end
