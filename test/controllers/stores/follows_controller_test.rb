require "test_helper"

class Stores::FollowsControllerTest < ActionDispatch::IntegrationTest
  TURBO_ACCEPT = "text/vnd.turbo-stream.html, text/html, application/xhtml+xml".freeze

  setup do
    @store = stores(:confirmed_store)
    # The :pending fixture is unconfirmed — Devise rejects its sign_in — so
    # the follower is a fresh confirmed user (who doesn't own the store).
    @user = User.create!(email: "follower@example.com", username: "follower",
                         password: "password123", confirmed_at: Time.current)
    sign_in @user
    # Warden's test-mode sign_in only covers the next request — warm the
    # session up with one successful request first (see the account tests).
    get "/en/s/#{@store.slug}"
    assert_response :success
  end

  def turbo_headers
    { "Accept" => TURBO_ACCEPT }
  end

  # --- Authentication -----------------------------------------------------------

  test "anonymous HTML follow redirects to sign in" do
    sign_out @user

    post "/en/s/#{@store.slug}/follow"

    assert_response :redirect
    assert_redirected_to "/en/users/sign_in"
    assert_equal 0, Follow.count
  end

  test "anonymous turbo follow redirects to sign in (Devise 5 treats turbo_stream as navigational)" do
    sign_out @user

    post "/en/s/#{@store.slug}/follow", headers: turbo_headers

    assert_response :redirect
    assert_redirected_to "/en/users/sign_in"
    assert_equal 0, Follow.count
  end

  test "unknown store slug is 404" do
    post "/en/s/ghost-store/follow", headers: turbo_headers
    assert_response :not_found

    delete "/en/s/ghost-store/follow", headers: turbo_headers
    assert_response :not_found
  end

  # --- Create / destroy -----------------------------------------------------------

  test "create follows the store and streams the button and the count" do
    assert_difference -> { @store.follows.count }, 1 do
      post "/en/s/#{@store.slug}/follow", headers: turbo_headers
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=?][target=?]", "replace", "follow_store_#{@store.id}"
    assert_select "turbo-stream[action=?][target=?]", "replace", "followers_count_store_#{@store.id}"
    assert_select "turbo-stream[target=?] button", "follow_store_#{@store.id}", "Following"
    assert @user.reload.following?(@store)
    assert_equal 1, @store.reload.followers_count
  end

  test "destroy unfollows and streams the Follow button back" do
    @user.follows.create!(store: @store)

    assert_difference -> { @store.follows.count }, -1 do
      delete "/en/s/#{@store.slug}/follow", headers: turbo_headers
    end

    assert_response :success
    assert_select "turbo-stream[target=?] button", "follow_store_#{@store.id}", "Follow"
    assert_not @user.reload.following?(@store)
    assert_equal 0, @store.reload.followers_count
  end

  test "turbo responses keep the compact styling when the form asked for it" do
    post "/en/s/#{@store.slug}/follow?compact=1", headers: turbo_headers

    assert_response :success
    assert_match "px-3 py-1.5 text-xs", response.body
  end

  test "following your own store is a no-op" do
    sign_in users(:confirmed)
    get "/en/s/#{@store.slug}"
    assert_response :success

    assert_no_difference -> { Follow.count } do
      post "/en/s/#{@store.slug}/follow", headers: turbo_headers
    end

    assert_response :success
    # The button partial renders nothing for the owner, so the stream just
    # empties the follow slot instead of showing a working button.
    assert_select "turbo-stream[action=?][target=?]", "replace", "follow_store_#{@store.id}"
    assert_no_match "<form", response.body
  end

  test "duplicate follow is a no-op" do
    @user.follows.create!(store: @store)

    assert_no_difference -> { Follow.count } do
      post "/en/s/#{@store.slug}/follow", headers: turbo_headers
    end

    assert_response :success
  end

  test "HTML create redirects back with a success flash" do
    post "/en/s/#{@store.slug}/follow", headers: { "Referer" => "/en/s/#{@store.slug}" }

    assert_response :see_other
    assert_redirected_to "/en/s/#{@store.slug}"
    assert @user.reload.following?(@store)
    assert_equal I18n.t("stores.follows.create.success", store: @store.display_name, locale: :en),
                 flash[:notice]
  end

  test "HTML destroy redirects back with a success flash" do
    @user.follows.create!(store: @store)

    delete "/en/s/#{@store.slug}/follow", headers: { "Referer" => "/en/s/#{@store.slug}" }

    assert_response :see_other
    assert_redirected_to "/en/s/#{@store.slug}"
    assert_not @user.reload.following?(@store)
    assert_equal I18n.t("stores.follows.destroy.success", store: @store.display_name, locale: :en),
                 flash[:notice]
  end

  # --- Button placement -------------------------------------------------------

  test "store page shows the follow button to other users" do
    get "/en/s/#{@store.slug}"

    assert_response :success
    assert_select "div#follow_store_#{@store.id} form[action=?] button",
                  "/en/s/#{@store.slug}/follow", "Follow"
  end

  test "store page hides the follow button on your own store" do
    sign_in users(:confirmed)
    get "/en/s/#{@store.slug}"

    assert_response :success
    assert_select "div#follow_store_#{@store.id}", 0
  end

  test "anonymous store page links the follow button to sign in" do
    sign_out @user
    get "/en/s/#{@store.slug}"

    assert_response :success
    assert_select "div#follow_store_#{@store.id} > a[href=?]", "/en/users/sign_in"
  end

  test "listing seller box renders the compact follow button" do
    listing = publish(create_listing(title: "Corsair HS80 RGB Wireless Headset"))

    get "/en/l/#{listing.slug}"

    assert_response :success
    assert_select "div#follow_store_#{@store.id} form[action^=?] button",
                  "/en/s/#{@store.slug}/follow", "Follow"
    assert_match "px-3 py-1.5 text-xs", response.body
  end
end
