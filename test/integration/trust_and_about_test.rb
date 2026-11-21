require "test_helper"

class TrustAndAboutTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
    Setting.set("support_email", "support@example.test")
    Setting.set("support_phone", "+34 900 111 222")
    Setting.set("support_hours", "Mon-Fri 9-18")
  end

  test "trust page renders live stats, contact details and FAQ structured data" do
    get "/es/trust"

    assert_response :success
    assert_select "h1", text: I18n.t("content.trust.hero_title", locale: :es)
    assert_includes response.body, Setting.get("support_email")
    assert_includes response.body, Setting.get("support_phone")
    assert_includes response.body, "\"@type\":\"FAQPage\""
    assert_select "details", minimum: 8
  end

  test "trust page uses fallback copy instead of invented numbers when data is small" do
    get "/es/trust"

    assert_response :success
    assert_includes response.body, I18n.t("content.trust.stats.completed_orders.fallback", locale: :es)
  end

  test "about page renders mission, how it works and team initials" do
    get "/es/about"

    assert_response :success
    assert_select "h1", text: I18n.t("content.about.hero_title", locale: :es)
    assert_includes response.body, I18n.t("content.about.why.title", locale: :es)
    assert_select "span", text: "OP"
  end
end
