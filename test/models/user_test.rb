require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "generates a username when none is provided" do
    user = User.create!(
      email: "new-user@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      first_name: "Nina",
      last_name: "New",
      confirmed_at: Time.current
    )

    assert_match(/\A[A-Za-z]+-[A-Za-z]+#\d{4}\z/, user.username)
  end

  test "display_name prefers the store name" do
    assert_equal "Falcon Tech", users(:seller).display_name
    assert_equal "Brave-Otter#5678", users(:buyer).display_name
  end

  test "from_omniauth creates a confirmed user" do
    auth = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "google-uid-123",
      info: { email: "oauth-user@example.com", first_name: "Olga", last_name: "OAuth" }
    )

    assert_difference -> { User.count }, 1 do
      @user = User.from_omniauth(auth)
    end

    assert @user.persisted?
    assert @user.confirmed?
    assert_equal "google_oauth2", @user.provider
    assert_equal "google-uid-123", @user.uid
    assert @user.username.present?
  end

  test "from_omniauth links an existing email" do
    auth = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "google-uid-456",
      info: { email: users(:buyer).email, first_name: "Bruno", last_name: "Buyer" }
    )

    assert_no_difference -> { User.count } do
      @user = User.from_omniauth(auth)
    end

    assert_equal users(:buyer).id, @user.id
    assert_equal "google-uid-456", @user.uid
  end

  test "soft_delete! keeps the record but marks it deleted" do
    user = users(:buyer)
    user.soft_delete!

    assert user.deleted?
    assert_not user.active_account?
  end
end
