require "test_helper"

class Account::PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:confirmed)
    sign_in @user
    # Session warm-up (see Account::AddressesControllerTest).
    get "/en/account/password/edit"
    assert_response :success
  end

  def password_params(overrides = {})
    { user: {
      current_password: "password123",
      password: "newsecret99",
      password_confirmation: "newsecret99"
    }.merge(overrides) }
  end

  # --- Authentication -----------------------------------------------------------

  test "requires a signed-in user" do
    sign_out @user

    get "/en/account/password/edit"
    assert_redirected_to "/en/users/sign_in"

    patch "/en/account/password", params: password_params
    assert_redirected_to "/en/users/sign_in"
  end

  # --- Edit ---------------------------------------------------------------------

  test "edit renders the password form" do
    assert_select "form[action=?]", "/en/account/password"
    assert_select "input[type=password][name=?]", "user[current_password]"
    assert_select "input[type=password][name=?]", "user[password]"
    assert_select "input[type=password][name=?]", "user[password_confirmation]"
  end

  # --- Update -------------------------------------------------------------------

  test "update changes the password and keeps the user signed in" do
    patch "/en/account/password", params: password_params

    assert_redirected_to "/en/account/password/edit"
    assert @user.reload.valid_password?("newsecret99")
    assert_not @user.valid_password?("password123")

    # bypass_sign_in: the session survives the password rotation.
    get "/en/account/profile/edit"
    assert_response :success
  end

  test "update rejects a wrong current password" do
    patch "/en/account/password", params: password_params(current_password: "wrongpassword")

    assert_response :unprocessable_entity
    assert_select "form[action=?] input[name=?]", "/en/account/password", "user[current_password]"
    assert @user.reload.valid_password?("password123")
  end

  test "update rejects mismatched confirmation with 422" do
    patch "/en/account/password", params: password_params(password_confirmation: "somethingelse")

    assert_response :unprocessable_entity
    assert @user.reload.valid_password?("password123")
  end
end
