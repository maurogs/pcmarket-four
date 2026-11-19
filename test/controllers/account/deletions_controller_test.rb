require "test_helper"

class Account::DeletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:confirmed)
    sign_in @user
    # Warden's test-mode sign_in only injects the user into the *next*
    # request; warm the session up with one successful request first.
    get "/en/account/deletion"
    assert_response :success
  end

  # --- Authentication -----------------------------------------------------------

  test "requires a signed-in user" do
    sign_out @user

    get "/en/account/deletion"
    assert_redirected_to "/en/users/sign_in"

    delete "/en/account/deletion", params: { user: { confirmation: "password123" } }
    assert_redirected_to "/en/users/sign_in"
  end

  # --- Show ---------------------------------------------------------------------

  test "show lists the consequences and asks for the current password" do
    assert_select "input[type=password][name=?]", "user[confirmation]"
    assert_select "form[action=?][method=post]", "/en/account/deletion" do
      # form_with method: :delete posts via the _method override.
      assert_select "input[type=hidden][name=?]", "_method"
    end
    assert_select "li", text: I18n.t("account.deletions.show.consequences.reviews", locale: :en)
  end

  test "show asks for the username instead of a password for omniauth-only accounts" do
    @user.update_columns(provider: "google", uid: "999", encrypted_password: "")
    sign_in @user # encrypted_password feeds Devise's session salt — re-sign in.

    get "/en/account/deletion"

    assert_response :success
    assert_select "input[type=text][name=?]", "user[confirmation]"
    assert_select "input[type=password][name=?]", "user[confirmation]", 0
  end

  # --- Destroy --------------------------------------------------------------------

  test "destroy with a wrong password re-renders with 422 and keeps the account" do
    delete "/en/account/deletion", params: { user: { confirmation: "wrong-password" } }

    assert_response :unprocessable_entity
    @user.reload
    assert_not_predicate @user, :deleted?
    assert_equal "confirmed@example.com", @user.email
    assert_equal "confirmeduser", @user.username

    # Still signed in — the failed attempt must not sign anyone out.
    get "/en/account/profile/edit"
    assert_response :success
  end

  test "destroy with a blank confirmation is rejected" do
    delete "/en/account/deletion", params: { user: { confirmation: "" } }

    assert_response :unprocessable_entity
    assert_not_predicate @user.reload, :deleted?
  end

  test "destroy with the correct password deletes, signs out and redirects home" do
    delete "/en/account/deletion", params: { user: { confirmation: "password123" } }

    assert_redirected_to "/en"
    assert_equal I18n.t("account.deletions.destroy.success", locale: :en), flash[:notice]

    @user.reload
    assert_predicate @user, :deleted?
    assert_equal "deleted-#{@user.id}@deleted.invalid", @user.email

    get "/en/account/profile/edit"
    assert_redirected_to "/en/users/sign_in"
  end

  test "omniauth-only users confirm with their username" do
    @user.update_columns(provider: "google", uid: "999", encrypted_password: "")
    sign_in @user

    delete "/en/account/deletion", params: { user: { confirmation: "confirmeduser" } }

    assert_redirected_to "/en"
    assert_predicate @user.reload, :deleted?
  end

  test "a deleted user cannot sign back in" do
    delete "/en/account/deletion", params: { user: { confirmation: "password123" } }
    assert_redirected_to "/en"

    # Even with the (anonymized) email and the still-valid password hash,
    # Devise refuses the session through active_for_authentication?.
    post "/en/users/sign_in", params: { user: { email: @user.reload.email,
                                                password: "password123" } }

    assert_redirected_to "/en/users/sign_in"
    assert_equal I18n.t("devise.failure.deleted", locale: :en), flash[:alert]
  end
end
