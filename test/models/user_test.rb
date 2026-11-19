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

  test "notify? defaults transactional keys on and the rest off" do
    user = users(:confirmed)
    assert_empty user.notification_preferences

    %w[order_updates messages offers].each { |key| assert user.notify?(key), "#{key} should default on" }
    %w[price_drops saved_search_alerts followed_store_listings newsletter]
      .each { |key| assert_not user.notify?(key), "#{key} should default off" }
  end

  test "notify? reads stored preferences over the defaults" do
    user = users(:confirmed)
    user.update!(notification_preferences: { "order_updates" => false, "newsletter" => true })

    assert_not user.notify?("order_updates")
    assert user.notify?("newsletter")
  end

  test "notify? prefers per-channel settings over the flat map" do
    user = User.new(notification_preferences: { "offers" => { "email" => false },
                                               "newsletter" => { "email" => true } })

    assert_not user.notify?("offers")
    assert user.notify?("newsletter", :email)
    assert_not user.notify?("newsletter", :sms)
  end

  test "notification_preferences rejects unknown keys" do
    user = users(:confirmed)
    user.notification_preferences = { "bogus" => true }

    assert_not user.valid?
    assert_includes user.errors[:notification_preferences], "is invalid"
  end

  test "marketing_opt_in_at follows marketing_opt_in" do
    user = users(:pending)
    user.update!(marketing_opt_in: true)
    assert_not_nil user.marketing_opt_in_at

    user.update!(marketing_opt_in: false)
    assert_nil user.marketing_opt_in_at
  end

  test "avatar rejects images over 5 MB" do
    user = users(:confirmed)
    user.avatar.attach(io: StringIO.new("x" * (6 * 1024 * 1024)),
                       filename: "big.png", content_type: "image/png")

    assert_not user.valid?
    assert_includes user.errors[:avatar], "is too large (maximum 5 MB)"
  end
end
