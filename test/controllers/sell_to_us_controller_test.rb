require "test_helper"

# "Sell to us" (instant offer) page behind the sell_to_us_enabled flag
# (Phase 3 step 6). Moved out of pages_controller_test.rb and extended with
# the link-gating checks.
class SellToUsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @flag = Setting.create!(key: "sell_to_us_enabled", value: "true",
                            value_type: "boolean", group: "sales",
                            description_key: "settings.descriptions.sell_to_us_enabled")
  end

  test "renders when the feature flag is enabled" do
    get "/sell_to_us"
    assert_response :success
  end

  test "renders in all locales without missing translations" do
    I18n.available_locales.map(&:to_s).each do |locale|
      get "/#{locale}/sell_to_us"
      assert_response :success
      assert_no_match "translation missing", response.body
    end
  end

  test "404s when the feature flag is disabled" do
    @flag.update!(value: "false")
    get "/sell_to_us"
    assert_response :not_found
  end

  test "404s when the flag is missing entirely" do
    @flag.destroy!
    get "/sell_to_us"
    assert_response :not_found
  end

  test "offer CTA is a mailto to the support email" do
    get "/en/sell_to_us"
    assert_select "a[href^='mailto:support@pcmarket.example']"
  end

  test "header and footer hide sell-to-us links when the flag is off" do
    @flag.update!(value: "false")

    get "/en"
    assert_no_match "sell_to_us", response.body
    get "/en/sell"
    assert_no_match "sell_to_us", response.body
  end

  test "header shows the sell-to-us button when the flag is on" do
    get "/en"
    assert_select "a[href=?]", "/en/sell_to_us"
  end
end
