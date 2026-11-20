require "test_helper"

class Seller::DashboardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:confirmed)
    @store = stores(:confirmed_store)
    sign_in @user
    # Warden's test-mode sign_in only injects the user into the *next* request;
    # warm the session up with one successful request first (same trick as the
    # listings tests).
    get "/en/seller/listings"
    assert_response :success
  end

  # A second, store-less seller. Must be confirmed — Devise's confirmable
  # rejects sign_in for unconfirmed users (the :pending fixture won't sign in).
  def storeless_seller
    @storeless_seller ||= User.create!(
      email: "dash-seller-two@example.com", username: "dashsellertwo",
      password: "password123", confirmed_at: Time.current
    )
  end

  # --- Authentication ----------------------------------------------------------

  test "requires a signed-in user" do
    sign_out @user

    get "/en/seller/dashboard"
    assert_redirected_to "/en/users/sign_in"
  end

  test "a seller without a store is sent to open one" do
    other = storeless_seller
    sign_out @user
    sign_in other
    get "/en/seller/listings" # warm the session up

    get "/en/seller/dashboard"
    assert_redirected_to "/en/seller/store/new"
  end

  # --- Rendering -----------------------------------------------------------------

  test "renders the greeting, KPI cards and quick actions" do
    publish(create_listing(title: "Dashboard Published Graphics Card", views_count: 42))

    get "/en/seller/dashboard"

    assert_response :success
    assert_select "h1", text: /Confirmed User/
    assert_select "dl div.card" do
      assert_select "dt", text: /Active listings/
      assert_select "dd", text: "1"
    end
    assert_select "dl div.card dt", text: /Total views/
    assert_select "dd", text: "42"
    assert_select "a[href=?]", "/en/seller/listings/new", text: /List an item/
    assert_select "a[href=?]", "/en/seller/store/edit", text: "Store settings"
    assert_select "a[href=?]", "/en/s/confirmed-store", text: "View public store"
  end

  test "a new seller sees the onboarding checklist instead of the panels" do
    get "/en/seller/dashboard"

    assert_response :success
    assert_select "h2", text: "Get your store ready"
    assert_select "li", text: /Create your first listing/
    # The sold chart and attention panels are hidden while onboarding.
    assert_select "h2", text: "Sold per day", count: 0
    assert_select "h2", text: "Needs attention", count: 0
  end

  test "shows the sold chart and the needs-attention panel once listings exist" do
    sold = publish(create_listing(title: "Chart Sold Graphics Card"))
    sold.mark_sold!

    rejected = create_listing(title: "Attention Rejected RAM")
    attach_photo(rejected)
    rejected.submit!
    rejected.reject!
    rejected.update!(rejection_reason: "Photos do not match the item.")

    get "/en/seller/dashboard"

    assert_response :success
    assert_select "h2", text: "Sold per day"
    assert_select "h2", text: "Get your store ready", count: 0
    assert_select "h2", text: "Needs attention"
    assert_select "li", text: /Attention Rejected RAM/
    assert_select "li", text: /Photos do not match the item\./
    assert_select "a[href=?]", "/en/seller/listings/#{rejected.to_param}/edit", text: "Fix"
  end

  # --- Period switcher -------------------------------------------------------------

  test "the period switcher marks the active period and sanitizes unknown values" do
    get "/en/seller/dashboard"
    assert_select "nav a[href=?][aria-current=page]", "/en/seller/dashboard?period=30d"

    get "/en/seller/dashboard?period=7d"
    assert_response :success
    assert_select "nav a[href=?][aria-current=page]", "/en/seller/dashboard?period=7d"

    get "/en/seller/dashboard?period=bogus"
    assert_response :success
    assert_select "nav a[href=?][aria-current=page]", "/en/seller/dashboard?period=30d"
  end

  # --- Sidebar wiring -----------------------------------------------------------------

  test "the seller sidebar links to the dashboard" do
    get "/en/seller/dashboard"

    assert_response :success
    assert_select "nav[aria-label='Seller area']" do
      assert_select "a[href=?]", "/en/seller/dashboard", text: "Dashboard"
      assert_select "span[aria-disabled=true]", count: 0
    end
  end
end
