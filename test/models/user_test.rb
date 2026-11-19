require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup { I18n.locale = :en }

  test "fixtures are valid" do
    assert users(:confirmed).valid?
    assert users(:confirmed).confirmed?
  end

  test "username format is enforced" do
    user = User.new(email: "new@example.com", username: "bad name!",
                    password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:username], "is invalid"
  end

  test "username uniqueness ignores case" do
    user = User.new(email: "other@example.com", username: "CONFIRMEDuser",
                    password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:username], "has already been taken"
  end

  test "full_name falls back to username" do
    assert_equal "Confirmed User", users(:confirmed).full_name
    assert_equal "pendinguser", users(:pending).full_name
  end

  test "generate_username sanitizes and de-duplicates" do
    base = User.generate_username("Ada Lovelace!")
    assert_match(/\A[a-z0-9_]+\z/, base)

    unique = User.generate_username("confirmeduser")
    assert_not_equal "confirmeduser", unique
  end

  test "from_omniauth creates a confirmed user" do
    auth = OmniAuth::AuthHash.new(
      provider: "google", uid: "1234567890",
      info: { email: "google.user@example.com", first_name: "Ada", last_name: "Lovelace" }
    )

    user = User.from_omniauth(auth)
    assert_predicate user, :persisted?
    assert_predicate user, :confirmed?
    assert_equal "ada_lovelace", user.username
    assert_equal "google.user@example.com", user.email

    # Second call finds the same record.
    assert_equal user.id, User.from_omniauth(auth).id
  end
end
