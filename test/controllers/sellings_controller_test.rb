require "test_helper"

# "Sell on PCMarket" landing page (Phase 3 step 6).
class SellingsControllerTest < ActionDispatch::IntegrationTest
  I18n.available_locales.map(&:to_s).each do |locale|
    test "renders in #{locale} without missing translations" do
      get "/#{locale}/sell"
      assert_response :success
      assert_select "html[lang=?]", locale
      assert_no_match "translation missing", response.body
    end
  end

  test "anonymous responses are publicly cacheable for an hour" do
    get "/en/sell"
    assert_match(/public/, response.headers["Cache-Control"])
    assert_match(/max-age=#{1.hour.to_i}/, response.headers["Cache-Control"])
  end

  test "hero and final CTAs link to the sell flow" do
    get "/en/sell"
    # Header and footer add their own sell links on top of the two CTAs.
    assert_select "a[href=?]", "/en/seller/listings/new", minimum: 2
  end

  test "fee copy shows the launch promo while commission is disabled" do
    get "/en/sell"
    assert_match "0% commission during launch", response.body
  end

  test "fee copy shows the configured commission when enabled" do
    set_setting("commission_enabled", true)
    set_setting("commission_percent", 7.5, value_type: "float")

    get "/en/sell"
    assert_match "7.5%", response.body
    assert_no_match "0% commission during launch", response.body
  end

  test "payout copy follows the payments flag" do
    get "/en/sell"
    assert_match "pays you on delivery", response.body

    set_setting("payments_enabled", true)
    get "/en/sell"
    assert_no_match "pays you on delivery", response.body
    assert_match "pays through PCMarket", response.body
  end

  test "featured stores appear when sellers have sales" do
    store = stores(:confirmed_store)
    store.update_columns(sales_count: 42, rating_avg: 4.8, ratings_count: 30)

    get "/en/sell"
    assert_select "a[href=?]", "/en/s/#{store.slug}"
    assert_match "42 sales", response.body
  end

  test "featured stores and recently sold sections are hidden when empty" do
    get "/en/sell"
    assert_no_match "Featured stores", response.body
    assert_no_match "Recently sold", response.body
  end

  test "recently sold scroller shows sold listings" do
    sold = publish(create_listing(title: "ASRock Radeon RX 6600 Phantom Gaming"))
    sold.mark_sold!

    get "/en/sell"
    assert_select "a[href=?]", "/en/l/#{sold.slug}"
  end

  test "home CTA and footer link to the selling page" do
    get "/en"
    assert_select "a[href=?]", "/en/sell", count: 2
  end
end
