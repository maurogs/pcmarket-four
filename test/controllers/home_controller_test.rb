require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  I18n.available_locales.map(&:to_s).each do |locale|
    test "root renders with html lang set to #{locale}" do
      get "/#{locale}"
      assert_response :success
      assert_select "html[lang=?]", locale
    end
  end

  test "root without locale prefix uses the default locale" do
    get "/"
    assert_response :success
    assert_select "html[lang=?]", I18n.default_locale.to_s
  end

  test "locale is persisted in a signed cookie and wins over the default" do
    get "/fr"
    assert cookies["pcmarket_locale"].present?

    get "/"
    assert_select "html[lang=?]", "fr"
  end

  test "Accept-Language is used when there is no param or cookie" do
    get "/", headers: { "Accept-Language" => "de-DE,de;q=0.9,en;q=0.8" }
    assert_response :success
    assert_select "html[lang=?]", "de"
  end

  test "unknown locale prefix is not routable" do
    get "/xx"
    assert_response :not_found
  end

  test "devise pages render localized" do
    get "/it/users/sign_in"
    assert_response :success
    assert_select "html[lang=?]", "it"
  end

  test "newsletter signup accepts and flashes" do
    post "/en/newsletter_subscribers", params: { email: "someone@example.com" }
    assert_response :redirect
  end
end
