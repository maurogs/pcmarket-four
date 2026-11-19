require "test_helper"

class NavigationMenuTest < ActiveSupport::TestCase
  include CatalogHelpers

  setup do
    @previous_locale = I18n.locale
    I18n.locale = :en
    Rails.cache.clear
  end

  teardown do
    I18n.locale = @previous_locale
    Rails.cache.clear
  end

  test "items include the catalogued fixture categories only" do
    keys = NavigationMenu.items(locale: "en").map(&:key)

    assert_equal %w[new gaming_pcs gpus components], keys
  end

  test "gpu item links brands to chipset filter paths" do
    gpus = NavigationMenu.items(locale: "en").find { |item| item.key == "gpus" }
    hrefs = gpus.columns.flat_map(&:links).map(&:href)

    assert_includes hrefs, "/en/c/gpus?specs%5Bgpu_chipset%5D%5B%5D=nvidia"
    assert_includes hrefs.map { |href| href.split("?").first }, "/en/c/gpus"
  end

  test "sell to us promo follows the feature flag" do
    promos = -> { NavigationMenu.items(locale: "en").flat_map { |i| i.promos || [] }.map(&:key) }
    assert_not_includes promos.call, "sell_to_us"

    set_setting("sell_to_us_enabled", true)
    assert_includes promos.call, "sell_to_us"
  end

  test "cache stamp changes when catalog data changes" do
    stamp = NavigationMenu.cache_stamp
    assert_equal stamp, NavigationMenu.cache_stamp

    categories(:gpus).touch(:updated_at)
    assert_not_equal stamp, NavigationMenu.cache_stamp
  end
end
