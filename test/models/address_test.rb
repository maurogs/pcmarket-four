require "test_helper"

class AddressTest < ActiveSupport::TestCase
  def build_address(overrides = {})
    Address.new({
      user: users(:confirmed),
      country: countries(:es),
      first_name: "Ana",
      last_name: "García",
      street_line1: "Calle Mayor 1",
      city: "Madrid",
      province: "28",
      postal_code: "28001"
    }.merge(overrides))
  end

  def enabled_france
    countries(:fr).tap { |fr| fr.update!(enabled: true, launched_at: Time.zone.parse("2026-06-01")) }
  end

  # --- Validations ----------------------------------------------------------

  test "valid Spanish address with matching province and postal prefix" do
    assert_predicate build_address, :valid?
  end

  test "requires user, country, names, street, city and postal code" do
    address = build_address(user: nil, country: nil, first_name: nil, last_name: nil,
      street_line1: nil, city: nil, postal_code: nil)
    assert_not_predicate address, :valid?

    %i[user country].each do |attribute|
      assert_includes address.errors[attribute], I18n.t("errors.messages.required"),
        "#{attribute} should be required"
    end
    %i[first_name last_name street_line1 city postal_code].each do |attribute|
      assert_includes address.errors[attribute], I18n.t("errors.messages.blank"),
        "#{attribute} should be required"
    end
  end

  test "Spanish postal code must be five digits" do
    %w[2801 28001A ABCDE].each do |postal_code|
      address = build_address(postal_code: postal_code)
      assert_not_predicate address, :valid?, "#{postal_code} should be rejected"
      assert_includes address.errors[:postal_code], I18n.t("errors.messages.invalid")
    end
  end

  test "Spanish address requires a known province" do
    address = build_address(province: nil)
    assert_not_predicate address, :valid?
    assert_includes address.errors[:province], I18n.t("errors.messages.blank")

    address = build_address(province: "99")
    assert_not_predicate address, :valid?
    assert_includes address.errors[:province], I18n.t("errors.messages.inclusion")
  end

  test "Spanish province must match the postal code prefix" do
    address = build_address(province: "08", postal_code: "28001")
    assert_not_predicate address, :valid?
    assert_includes address.errors[:province],
      I18n.t("activerecord.errors.models.address.attributes.province.postal_code_mismatch")
  end

  test "country must be enabled" do
    address = build_address(country: countries(:fr))
    assert_not_predicate address, :valid?
    assert_includes address.errors[:country],
      I18n.t("activerecord.errors.models.address.attributes.country.not_enabled")
  end

  test "non-Spain addresses skip Spanish rules and drop the province" do
    france = enabled_france
    address = build_address(country: france, province: "28", postal_code: "75001")

    assert_predicate address, :valid?
    assert_nil address.province
  end

  # --- Default shipping address ---------------------------------------------

  test "first address becomes the default automatically" do
    address = build_address.tap { |a| a.save! }

    assert_predicate address, :default_shipping?
    assert_equal address, users(:confirmed).reload.default_address
  end

  test "later addresses are not default" do
    first = build_address.tap { |a| a.save! }
    second = build_address(label: "Office", street_line1: "Otra 2").tap { |a| a.save! }

    assert_predicate first, :default_shipping?
    assert_not_predicate second, :default_shipping?
  end

  test "creating with default_shipping unsets the previous default" do
    first = build_address.tap { |a| a.save! }
    second = build_address(label: "Office", default_shipping: true).tap { |a| a.save! }

    assert_predicate second.reload, :default_shipping?
    assert_not_predicate first.reload, :default_shipping?
  end

  test "make_default! unsets the other addresses" do
    first = build_address.tap { |a| a.save! }
    second = build_address(label: "Office", street_line1: "Otra 2").tap { |a| a.save! }

    second.make_default!

    assert_predicate second.reload, :default_shipping?
    assert_not_predicate first.reload, :default_shipping?
    assert_equal second, users(:confirmed).reload.default_address
  end

  test "defaults_first scope puts the default on top" do
    first = build_address.tap { |a| a.save! }
    second = build_address(label: "Office", street_line1: "Otra 2").tap { |a| a.save! }
    second.make_default!

    assert_equal [ second, first ], users(:confirmed).addresses.defaults_first.to_a
  end

  test "user destroy removes the addresses" do
    user = users(:pending)
    address = build_address(user: user).tap { |a| a.save! }

    assert_difference "Address.count", -1 do
      user.destroy!
    end
    assert_raises ActiveRecord::RecordNotFound do
      Address.find(address.id)
    end
  end

  # --- Formatting ------------------------------------------------------------

  test "formatted_lines and to_s render the address block" do
    address = build_address(company: "ACME SL", street_line2: "3ºB")

    assert_equal [ "Ana García", "ACME SL", "Calle Mayor 1", "3ºB", "28001 Madrid",
      "Madrid", I18n.t("countries.es") ], address.formatted_lines
    assert_equal address.formatted_lines.join(", "), address.to_s
  end

  test "formatted_lines skips blank optional parts" do
    assert_equal [ "Ana García", "Calle Mayor 1", "28001 Madrid", "Madrid",
      I18n.t("countries.es") ], build_address.formatted_lines
  end
end
