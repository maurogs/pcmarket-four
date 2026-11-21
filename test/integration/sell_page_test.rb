require "test_helper"

class SellPageTest < ActionDispatch::IntegrationTest
  test "sell page renders the selling flow and FAQ structured data" do
    get sell_path(locale: :en)

    assert_response :success
    assert_includes response.body, I18n.t("sell_page.hero.title", locale: :en)
    assert_includes response.body, I18n.t("sell_page.steps.list_title", locale: :en)
    assert_includes response.body, "FAQPage"
    assert_select "details", minimum: 6
  end

  test "sell page uses no-fee copy while commissions are disabled" do
    Setting.set("commissions_enabled", false)

    get sell_path(locale: :en)

    assert_response :success
    assert_includes response.body, I18n.t("sell_page.perks.commission_off", locale: :en)
  end

  test "sell page shows the commission rate when commissions are enabled" do
    Setting.set("commissions_enabled", true)
    Setting.set("commission_percent", 7)

    get sell_path(locale: :en)

    assert_response :success
    assert_includes response.body, "7% commission"
  end
end
