require "test_helper"

# The header account menu (_account_menu) and the shared _account_links list
# it renders alongside the mobile drawer. Both surfaces are in the DOM on
# every page, so positive assertions match either copy and negative ones must
# hold across both.
class HeaderAccountMenuTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:confirmed) # owns stores(:confirmed_store)
  end

  # --- Signed out ---------------------------------------------------------------

  test "signed out visitors see sign in and sign up links" do
    Setting.create!(key: "registrations_enabled", value: true, value_type: "boolean")

    get "/en"

    assert_response :success
    assert_select "a[href=?]", "/en/users/sign_in", text: "Sign in"
    assert_select "a[href=?]", "/en/users/sign_up", text: "Sign up"
  end

  test "sign up link is hidden when registrations are disabled" do
    Setting.create!(key: "registrations_enabled", value: false, value_type: "boolean")

    get "/en"

    assert_response :success
    assert_select "a[href=?]", "/en/users/sign_in"
    assert_select "a[href=?]", "/en/users/sign_up", count: 0
  end

  # --- Signed in ----------------------------------------------------------------

  test "signed in users see the buying links and a sign out form" do
    sign_in @owner

    get "/en"

    assert_response :success
    assert_select "a[href=?]", "/en/account/profile/edit", text: "Account settings"
    assert_select "form[action=?]", "/en/users/sign_out" do
      assert_select "input[type=hidden][value=delete]"
    end
  end

  test "unbuilt destinations render as disabled items, not links" do
    sign_in @owner

    get "/en"

    assert_response :success
    [ "My orders", "Messages & offers", "Wishlist" ].each do |label|
      assert_select "a", text: label, count: 0
      assert_select "span[aria-disabled=true]", text: /#{Regexp.escape(label)}/
    end
    assert_select "span", text: "Soon"
  end

  test "store owners see the store links" do
    sign_in @owner

    get "/en"

    assert_response :success
    assert_select "a[href=?]", "/en/s/confirmed-store", text: "Public profile"
    assert_select "a[href=?]", "/en/seller/store/edit", text: "Store settings"
    assert_select "a", text: "Open your store", count: 0
  end

  test "users without a store see the open your store link" do
    user = User.create!(email: "nostore@example.com", username: "nostore",
                        password: "password123", confirmed_at: Time.current)
    sign_in user

    get "/en"

    assert_response :success
    assert_select "a[href=?]", "/en/seller/store/new", text: "Open your store"
    assert_select "a", text: "Store settings", count: 0
  end

  # --- Roles --------------------------------------------------------------------

  test "admins see the admin item" do
    @owner.update!(role: :admin)
    sign_in @owner

    get "/en"

    assert_response :success
    assert_select "span[aria-disabled=true]", text: /Admin panel/
  end

  test "moderators see the admin item" do
    @owner.update!(role: :moderator)
    sign_in @owner

    get "/en"

    assert_response :success
    assert_select "span[aria-disabled=true]", text: /Admin panel/
  end

  test "regular users do not see the admin item" do
    assert @owner.user?

    sign_in @owner

    get "/en"

    assert_response :success
    assert_select "span[aria-disabled=true]", text: /Admin panel/, count: 0
  end
end
