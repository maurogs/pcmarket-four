require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  PagesController::PAGES.each do |page|
    test "allows the #{page} page" do
      get "/pages/#{page}"
      assert_response :success
    end
  end

  test "rejects unknown pages" do
    get "/pages/some-secret-page"
    assert_response :not_found
  end
end

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
end
