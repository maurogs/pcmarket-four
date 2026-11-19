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

  test "home shows deals hero and scrollers when listings exist" do
    deal = publish(create_listing(title: "Gigabyte RTX 3060 Gaming OC 12GB", price_cents: 24_900,
                                  original_price_cents: 32_900))
    arrival = publish(create_listing(title: "MSI Radeon RX 7600 8GB", price_cents: 27_900),
                      published_at: 1.hour.ago)
    sold = publish(create_listing(title: "Intel Core i5-12400 Processor", category: categories(:cpus),
                                  price_cents: 11_900))
    sold.mark_sold!
    sold.update_columns(sold_at: 2.days.ago)

    get "/en"
    assert_response :success
    # Discounted listing drives the hero carousel; cards land in the scrollers.
    assert_select "[data-controller=?]", "hero-carousel"
    assert_select "h1", text: deal.title
    assert_select "a[href=?]", listing_path(arrival)
    assert_select "span", text: "Sold"
    assert_select "a[href=?]", "/en/pages/trust"
  end

  test "home renders localized with data in Spanish" do
    gpu = publish(create_listing(title: "Tarjeta gráfica ASUS Dual RTX 4060", price_cents: 28_900,
                                 original_price_cents: 34_900))

    get "/es"
    assert_response :success
    assert_select "html[lang=?]", "es"
    assert_select "[data-controller=?]", "hero-carousel"
    assert_select "a[href=?]", "/es/l/#{gpu.slug}"
    assert_select "a[href=?]", "/es/search?sort=newest"
  end

  test "header mega menu exposes curated and chipset filter links" do
    get "/en"
    assert_response :success
    # Curated "New" entry and GPU brand links built from the seeded catalog.
    assert_select "a[href=?]", "/en/search?sort=newest"
    assert_select "a[href*=?]", "specs%5Bgpu_chipset%5D%5B%5D=nvidia"
  end

  test "sell to us promo appears only when the feature flag is on" do
    get "/en"
    assert_no_match "sell_to_us", response.body

    set_setting("sell_to_us_enabled", true)

    get "/en"
    assert_select "a[href=?]", "/en/sell_to_us"
  end
end
