require "test_helper"

class Account::NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:confirmed)
    sign_in @user
    # Session warm-up (see Account::AddressesControllerTest).
    get "/en/account/notifications/edit"
    assert_response :success
  end

  def notification_params(preferences = {}, marketing_opt_in: "0")
    defaults = {
      "order_updates" => "1", "messages" => "1", "offers" => "0", "price_drops" => "1",
      "saved_search_alerts" => "0", "followed_store_listings" => "0", "newsletter" => "1"
    }
    { user: { notification_preferences: defaults.merge(preferences),
              marketing_opt_in: marketing_opt_in } }
  end

  # --- Authentication -----------------------------------------------------------

  test "requires a signed-in user" do
    sign_out @user

    get "/en/account/notifications/edit"
    assert_redirected_to "/en/users/sign_in"

    patch "/en/account/notifications", params: notification_params
    assert_redirected_to "/en/users/sign_in"
  end

  # --- Edit ---------------------------------------------------------------------

  test "edit renders one checkbox per notification key plus the marketing opt-in" do
    User::NOTIFICATION_KEYS.each do |key|
      assert_select "input[type=checkbox][name=?]", "user[notification_preferences][#{key}]"
    end
    assert_select "input[type=checkbox][name=?]", "user[marketing_opt_in]"
  end

  test "edit pre-checks transactional keys and leaves opt-in keys off" do
    assert_select "input[name=?][checked]", "user[notification_preferences][order_updates]"
    assert_select "input[name=?][checked]", "user[notification_preferences][messages]"
    assert_select "input[name=?]:not([checked])", "user[notification_preferences][price_drops]"
    assert_select "input[name=?]:not([checked])", "user[notification_preferences][newsletter]"
  end

  # --- Update -------------------------------------------------------------------

  test "update persists the preferences as real booleans" do
    patch "/en/account/notifications", params: notification_params({ "offers" => "1", "order_updates" => "0" })

    assert_redirected_to "/en/account/notifications/edit"
    assert_equal({ "order_updates" => false, "messages" => true, "offers" => true,
                   "price_drops" => true, "saved_search_alerts" => false,
                   "followed_store_listings" => false, "newsletter" => true },
                 @user.reload.notification_preferences)
  end

  test "stored preferences drive notify? after the update" do
    patch "/en/account/notifications", params: notification_params({ "offers" => "1", "order_updates" => "0" })

    @user.reload
    assert_not @user.notify?("order_updates")
    assert @user.notify?("offers")
    assert @user.notify?("newsletter")
    assert_not @user.notify?("saved_search_alerts")
  end

  test "marketing opt-in is timestamped and clearing it removes the timestamp" do
    patch "/en/account/notifications", params: notification_params(marketing_opt_in: "1")

    @user.reload
    assert_predicate @user, :marketing_opt_in?
    assert_not_nil @user.marketing_opt_in_at

    patch "/en/account/notifications", params: notification_params(marketing_opt_in: "0")

    @user.reload
    assert_not_predicate @user, :marketing_opt_in?
    assert_nil @user.marketing_opt_in_at
  end
end
