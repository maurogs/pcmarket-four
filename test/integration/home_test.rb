require "test_helper"

class HomeTest < ActionDispatch::IntegrationTest
  test "serves Spanish by default at the root path" do
    get "/"

    assert_response :success
    assert_select "html[lang=?]", "es"
    assert_select "h1", text: I18n.t("home.title", locale: :es)
  end

  test "serves English under the locale prefix" do
    get "/en"

    assert_response :success
    assert_select "html[lang=?]", "en"
    assert_select "h1", text: I18n.t("home.title", locale: :en)
  end

  test "serves French under the locale prefix" do
    get "/fr"

    assert_response :success
    assert_select "html[lang=?]", "fr"
    assert_select "h1", text: I18n.t("home.title", locale: :fr)
  end
end
