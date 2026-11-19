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

  test "reviews tab shows published reviews with the rating summary" do
    create_review(rating: 5, title: "Fast shipping", body: "Everything as described.",
                  verified_purchase: true)
    create_review(rating: 3, title: "Slow dispatch", body: "Took two weeks to ship.",
                  seller_reply: "Sorry — we were on holiday.", seller_replied_at: Time.current)
    hidden = create_review(rating: 1, title: "Not visible", body: "Hidden from the tab.")
    hidden.update_column(:status, "hidden")
    Stores::RatingRecalculator.call(@store)

    get "/en/s/#{@store.slug}?tab=reviews"

    assert_response :success
    assert_match "Fast shipping", response.body
    assert_match "Slow dispatch", response.body
    assert_no_match "Not visible", response.body
    assert_match "pendinguser", response.body # review author username
    assert_match "4.0", response.body         # (5 + 3) / 2
    assert_match "2 reviews", response.body
    assert_match "Verified purchase", response.body
    assert_match "Sorry — we were on holiday.", response.body
    assert_select "[aria-label=?]", "Rating distribution"
  end

  test "reviews tab shows the empty state without reviews" do
    get "/en/s/#{@store.slug}?tab=reviews"

    assert_response :success
    assert_select "p.text-muted", text: I18n.t("stores.show.reviews.empty", locale: :en)
  end

  test "reviews tab paginates ten per page newest first" do
    11.times do |i|
      author = User.create!(email: "reviewer#{i}@example.com", username: "reviewer#{i}",
                            password: "password123", confirmed_at: Time.current)
      review = create_review(author: author, title: "Paginated review #{i}")
      review.update_columns(created_at: Time.current - i.days)
    end

    get "/en/s/#{@store.slug}?tab=reviews"
    assert_response :success
    assert_match "Paginated review 0", response.body
    assert_no_match "Paginated review 10", response.body

    get "/en/s/#{@store.slug}?tab=reviews&page=2"
    assert_response :success
    assert_match "Paginated review 10", response.body
  end

  test "outdated store slug 301s to the canonical URL" do
    # Model-created (not fixture) so FriendlyId records the slug history.
    store = Store.create!(user: users(:pending), name: "Redirect Test Store")
    store.update!(name: "Renamed Redirect Store")

    get "/en/s/redirect-test-store"

    assert_response :moved_permanently
    assert_redirected_to "/en/s/renamed-redirect-store"
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
