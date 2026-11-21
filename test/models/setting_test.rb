require "test_helper"

class SettingTest < ActiveSupport::TestCase
  test "returns stored values typed according to value_type" do
    assert_equal "PCMarket", Setting.get(:site_name)
    assert_equal 12, Setting.get("max_images_per_listing")
    assert_equal BigDecimal("5.0"), Setting.get("commission_percent")
    assert_equal true, Setting.get("listings_require_approval")
    assert_equal false, Setting.enabled?("commissions_enabled")
  end

  test "falls back to DEFAULTS when no row exists" do
    assert_equal 50, Setting.get("max_active_listings_per_user")
    assert_equal false, Setting.enabled?("sell_to_us_enabled")
  end

  test "accepts an explicit default when the key is unknown" do
    assert_equal "fallback", Setting.get("unknown_key", "fallback")
    assert_nil Setting.get("unknown_key")
  end

  test "caches values until the record is saved" do
    assert_equal "PCMarket", Setting.get("site_name")

    setting = Setting.find_by!(key: "site_name")
    setting.update_columns(value: "Changed behind the cache")
    assert_equal "PCMarket", Setting.get("site_name")

    setting.update!(value: "PCMarket Updated")
    assert_equal "PCMarket Updated", Setting.get("site_name")
  end

  test "set persists a typed value and invalidates the cache" do
    assert_equal "", Setting.get("announcement_bar_text")

    Setting.set("announcement_bar_text", "¡Bienvenido!")
    assert_equal "¡Bienvenido!", Setting.get("announcement_bar_text")
    assert_equal "string", Setting.find_by(key: "announcement_bar_text").value_type

    Setting.set("featured_price_cents", 799)
    assert_equal 799, Setting.get("featured_price_cents")
    assert_equal "integer", Setting.find_by(key: "featured_price_cents").value_type
  end

  test "ensure_defaults! creates every missing default idempotently" do
    Setting.delete_all

    assert_difference -> { Setting.count }, Setting::DEFAULTS.size do
      Setting.ensure_defaults!
    end

    assert_no_difference -> { Setting.count } do
      Setting.ensure_defaults!
    end

    Setting::DEFAULTS.each_key do |key|
      assert Setting.exists?(key: key), "expected default #{key} to be created"
    end
  end
end
