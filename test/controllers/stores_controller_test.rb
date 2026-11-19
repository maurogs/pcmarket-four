require "test_helper"

class StoresControllerTest < ActionDispatch::IntegrationTest
  setup { @store = stores(:confirmed_store) }

  test "show lists the store listings with sold ones last" do
    fresh = publish(create_listing(title: "ASUS ROG Strix RTX 4070 OC", price_cents: 59_900, store: @store))
    sold  = publish(create_listing(title: "Gigabyte GTX 1660 Super", price_cents: 16_900, store: @store),
                    published_at: 5.days.ago)
    sold.mark_sold!
    sold.update_columns(sold_at: 2.days.ago)

    get "/en/s/#{@store.slug}"
    assert_response :success
    assert_select "h1", text: @store.name
    assert_select "a[href=?]", listing_path(fresh)
    assert_match "Sold", response.body
    assert_operator response.body.index("ASUS ROG Strix"), :<, response.body.index("Gigabyte GTX 1660")
  end

  test "show never includes other sellers listings" do
    other_user = User.create!(email: "second-seller@example.com", username: "secondseller",
                              password: "password123", confirmed_at: Time.current)
    other_store = Store.create!(user: other_user, name: "Other Seller Shop", country: @store.country)
    publish(create_listing(title: "Zotac RTX 4080 AMP Extreme", price_cents: 99_900, store: other_store))

    get "/en/s/#{@store.slug}"
    assert_response :success
    assert_no_match "Zotac RTX 4080", response.body
  end

  test "about tab renders the bio" do
    @store.update!(bio: "We have been selling tested PC parts since 2019.")

    get "/en/s/#{@store.slug}?tab=about"
    assert_response :success
    assert_match "tested PC parts", response.body
  end

  test "reviews tab renders the placeholder summary" do
    get "/en/s/#{@store.slug}?tab=reviews"
    assert_response :success
    assert_match "Reviews open as soon as", response.body
  end

  test "vacation store shows the banner with its custom message" do
    @store.update!(vacation_mode: true, vacation_message: "Back from holidays on Monday.")

    get "/en/s/#{@store.slug}"
    assert_response :success
    assert_match "Back from holidays on Monday", response.body
  end

  test "unknown store slug is 404" do
    get "/en/s/ghost-store"
    assert_response :not_found
  end
end
