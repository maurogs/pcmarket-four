require "test_helper"

class HomeTest < ActionDispatch::IntegrationTest
  test "renders the home page in every available locale" do
    I18n.available_locales.each do |locale|
      get "/#{locale}"

      assert_response :success
      assert_select "html[lang=?]", locale.to_s
      assert_select "h1", text: I18n.t("home.hero.title", locale: locale)
      assert_select "link[rel='alternate'][hreflang=?]", locale.to_s
      assert_select "link[rel='alternate'][hreflang='x-default']", 1
      assert_select "script[type='application/ld+json']", 1
    end
  end

  test "root path serves Spanish by default" do
    get "/"

    assert_response :success
    assert_select "html[lang=?]", "es"
  end

  test "structured data includes organisation, website and search action" do
    get "/es"

    json = JSON.parse(css_select("script[type='application/ld+json']").first.text)
    types = json["@graph"].map { |node| node["@type"] }

    assert_includes types, "Organization"
    assert_includes types, "WebSite"

    website = json["@graph"].find { |node| node["@type"] == "WebSite" }
    assert_equal "SearchAction", website.dig("potentialAction", "@type")
  end

  test "header exposes every root menu category" do
    get "/es"

    assert_response :success
    assert_select "button[data-mega-menu-target='trigger']", minimum: 1
    assert_select "button[data-panel-id='mega-components']", 1
    assert_select "button[data-panel-id='mega-laptops']", 1
  end

  test "cookie consent banner is present for visitors without a choice" do
    get "/es"

    assert_select "[data-cookie-consent-target='banner']"
    assert_select "h2", text: I18n.t("layout.cookies.banner_title")
  end

  test "announcement bar only renders when configured" do
    Setting.set("announcement_bar_text", "")

    get "/es"
    assert_select "[data-controller='announcement']", count: 0

    Setting.set("announcement_bar_text", "Envío gratis esta semana")

    get "/es"
    assert_select "[data-controller='announcement']", 1
    assert_select "p", text: "Envío gratis esta semana"
  ensure
    Setting.set("announcement_bar_text", "")
  end

  test "sell to PCMarket link is only rendered when the feature flag is enabled" do
    Setting.set("sell_to_us_enabled", false)

    get "/es"
    assert_select "a", text: I18n.t("layout.header.sell_to_us"), count: 0

    Setting.set("sell_to_us_enabled", true)

    get "/es"
    assert_select "a", text: I18n.t("layout.header.sell_to_us"), minimum: 1
  ensure
    Setting.set("sell_to_us_enabled", false)
  end

  test "home page exposes listing cards for visible listings" do
    get "/es"

    assert_select "article", minimum: 1
    assert_select "a[href=?]", "/es/l/#{listings(:published_gpu).slug}", minimum: 1
  end

  test "language switcher preserves the current path and query string" do
    get "/en/l/#{listings(:published_gpu).slug}?q=rtx"

    expected = "/es/l/#{listings(:published_gpu).slug}?q=rtx"
    assert_select "a[hreflang='es'][href=?]", expected, minimum: 1
  end

  test "sold listings remain publicly viewable" do
    get "/es/l/#{listings(:sold_listing).slug}"

    assert_response :success
    assert_select "h1", text: listings(:sold_listing).title
  end
end
