require "test_helper"

class AccountSettingsTest < ActionDispatch::IntegrationTest
  setup do
    @buyer = users(:buyer)
    @seller = users(:seller)
  end

  test "account area requires authentication" do
    %i[account_path account_addresses_path new_account_deletion_path].each do |helper|
      get public_send(helper, locale: :es)
      assert_redirected_to new_user_session_path(locale: :es)
    end
  end

  test "renders the account profile page" do
    sign_in @buyer

    get account_path

    assert_response :success
    assert_select "html[lang=es]"
    assert_match I18n.t("account.profile.title"), response.body
    assert_select "input[name='user[username]']"
  end

  test "updates profile fields" do
    sign_in @buyer

    patch account_path, params: { user: { username: "Buyer-New#1", phone: "+34600111222", locale: "es" } }

    assert_redirected_to account_path(locale: :es)
    @buyer.reload
    assert_equal "Buyer-New#1", @buyer.username
    assert_equal "+34600111222", @buyer.phone
  end

  test "rejects an invalid username" do
    sign_in @buyer

    patch account_path, params: { user: { username: "no spaces allowed", locale: "es" } }

    assert_response :unprocessable_entity
    assert_match I18n.t("activerecord.attributes.user.username"), response.body
  end

  test "requires the current password to change it" do
    sign_in @buyer

    patch account_password_path, params: {
      current_password: "wrong", user: { password: "NewPassword123!", password_confirmation: "NewPassword123!" }
    }

    assert_response :unprocessable_entity
    assert_equal I18n.t("account.password.wrong_current"), flash[:alert]
  end

  test "changes the password with the current password" do
    sign_in @buyer

    patch account_password_path, params: {
      current_password: "Password123!",
      user: { password: "NewPassword123!", password_confirmation: "NewPassword123!" }
    }

    assert_redirected_to account_password_path(locale: :es)
    assert @buyer.reload.valid_password?("NewPassword123!")
  end

  test "addresses default switching unsets the previous default" do
    sign_in @buyer
    first = addresses(:buyer_address)
    assert first.default?

    post account_addresses_path, params: {
      address: {
        full_name: "Bruno Buyer", line1: "Gran Via 1", city: "Madrid",
        postal_code: "28013", country_code: "ES", default: "1"
      }
    }

    assert_redirected_to account_addresses_path(locale: :es)
    second = Address.order(:created_at).last
    assert second.default?
    assert_not first.reload.default?
  end

  test "creates an address with validation errors" do
    sign_in @buyer

    assert_no_difference -> { Address.count } do
      post account_addresses_path, params: { address: { full_name: "", city: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "notification preferences default to true except the newsletter" do
    sign_in @buyer

    get edit_account_notification_preferences_path
    assert_response :success

    patch account_notification_preferences_path, params: {
      notification_preferences: {
        email_messages: "0", email_offers: "1", email_order_updates: "1",
        email_saved_search_alerts: "1", email_price_drops_favourites: "1",
        email_newsletter: "1"
      }
    }

    assert_redirected_to edit_account_notification_preferences_path(locale: :es)
    @buyer.reload
    assert_not @buyer.notify_by_email?("email_messages")
    assert @buyer.notify_by_email?("email_order_updates")
    assert @buyer.notify_by_email?("email_newsletter")
    assert @buyer.accepts_marketing
  end

  test "data export returns the user's own records" do
    sign_in @buyer

    post account_data_export_path

    assert_response :success
    assert_equal "application/json", response.media_type
    payload = JSON.parse(response.body)
    assert_equal @buyer.id, payload["user"]["id"]
    assert payload.key?("listings")
    assert payload.key?("orders")
    assert payload.key?("favourites")
    assert_empty payload["listings"]
    assert_equal [ @seller.username ], Order.where(buyer_id: @buyer.id).map { |order| order.seller.username }.uniq
  end

  test "deletion rejects a wrong password" do
    sign_in @buyer

    post account_deletion_path, params: { current_password: "wrong" }

    assert_response :unprocessable_entity
    assert_not @buyer.reload.deleted?
  end

  test "deletion anonymises the account, archives listings and signs out" do
    sign_in @seller
    original_email = @seller.email

    post account_deletion_path, params: { current_password: "Password123!" }

    assert_redirected_to root_path(locale: :es)
    @seller.reload
    assert @seller.deleted?
    assert_not_equal original_email, @seller.email
    assert_match(/\Adeleted-user-/, @seller.username)
    assert_nil @seller.first_name
    assert @seller.listings.all?(&:archived?)
    assert Order.exists?(seller_id: @seller.id)

    get account_path(locale: :es)
    assert_redirected_to new_user_session_path(locale: :es)
  end

  test "locale follows the signed-in user's preference" do
    @buyer.update_columns(locale: "fr")
    sign_in @buyer

    get "/"

    assert_response :success
    assert_select "html[lang=fr]"
  end

  test "locale falls back to the Accept-Language header" do
    get "/", headers: { "Accept-Language" => "en-US,en;q=0.9,es;q=0.8" }

    assert_response :success
    assert_select "html[lang=en]"
  end

  test "root path remains reachable and defaults to Spanish" do
    get "/"

    assert_response :success
    assert_select "html[lang=es]"
  end
end
