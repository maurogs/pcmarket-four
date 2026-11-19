require "test_helper"

class Account::ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:confirmed)
    sign_in @user
    # Warden's test-mode sign_in only injects the user into the *next* request;
    # warm the session up with one successful request first (same trick as the
    # addresses tests).
    get "/en/account/profile/edit"
    assert_response :success
  end

  def profile_params(overrides = {})
    { user: {
      first_name: "Ana",
      last_name: "García",
      username: "confirmeduser",
      phone: "",
      locale: "es",
      email: "confirmed@example.com"
    }.merge(overrides) }
  end

  def upload(content, content_type, filename)
    Rack::Test::UploadedFile.new(StringIO.new(content), content_type, original_filename: filename)
  end

  # --- Authentication -----------------------------------------------------------

  test "requires a signed-in user" do
    sign_out @user

    get "/en/account/profile/edit"
    assert_redirected_to "/en/users/sign_in"

    patch "/en/account/profile", params: profile_params
    assert_redirected_to "/en/users/sign_in"
  end

  # --- Edit ---------------------------------------------------------------------

  test "edit renders the profile form prefilled" do
    assert_select "form[action=?][enctype=?]", "/en/account/profile", "multipart/form-data"
    assert_select "input[name=?][value=?]", "user[username]", "confirmeduser"
    assert_select "input[name=?][value=?]", "user[first_name]", "Confirmed"
    assert_select "input[name=?]", "user[email]"
    assert_select "select[name=?] option[value=?]", "user[locale]", "en"
    assert_select "input[type=file][name=?]", "user[avatar]"
  end

  test "email field is hidden for omniauth-only accounts" do
    @user.update_columns(provider: "google", uid: "1234", encrypted_password: "")
    # Clearing encrypted_password changes Devise's authenticatable_salt, which
    # invalidates the warm session — sign in again for this request.
    sign_in @user

    get "/en/account/profile/edit"

    assert_response :success
    assert_select "input[name=?]", "user[email]", 0
  end

  # --- Update -------------------------------------------------------------------

  test "update saves profile changes" do
    patch "/en/account/profile", params: profile_params(first_name: "Ana", phone: "600123456", locale: "en")

    assert_redirected_to "/en/account/profile/edit"
    @user.reload
    assert_equal "Ana", @user.first_name
    assert_equal "García", @user.last_name
    assert_equal "600123456", @user.phone
    assert_equal "en", @user.locale
  end

  test "update re-renders the form with 422 on invalid input" do
    patch "/en/account/profile", params: profile_params(username: "a b!")

    assert_response :unprocessable_entity
    assert_select "form[action=?] input[name=?]", "/en/account/profile", "user[username]"
    assert_equal "confirmeduser", @user.reload.username
  end

  test "update rejects a username taken by someone else" do
    patch "/en/account/profile", params: profile_params(username: "pendinguser")

    assert_response :unprocessable_entity
    assert_equal "confirmeduser", @user.reload.username
  end

  test "email change goes through reconfirmation" do
    patch "/en/account/profile", params: profile_params(email: "new@example.com")

    assert_redirected_to "/en/account/profile/edit"
    @user.reload
    assert_equal "confirmed@example.com", @user.email
    assert_equal "new@example.com", @user.unconfirmed_email
    assert_predicate @user, :pending_reconfirmation?
  end

  test "update attaches a valid avatar" do
    patch "/en/account/profile", params: profile_params(avatar: upload("fake png bytes", "image/png", "avatar.png"))

    assert_redirected_to "/en/account/profile/edit"
    assert_predicate @user.reload.avatar, :attached?
  end

  test "update rejects a non-image avatar with 422" do
    patch "/en/account/profile", params: profile_params(avatar: upload("not an image", "text/plain", "notes.txt"))

    assert_response :unprocessable_entity
    assert_not_predicate @user.reload.avatar, :attached?
  end
end
