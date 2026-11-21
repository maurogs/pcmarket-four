require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "sign up requires accepting the terms and records the acceptance" do
    get new_user_registration_path(locale: :es)

    assert_response :success
    assert_select "input#user_terms_accepted[required]"
    assert_select "input#user_accepts_marketing"

    assert_no_difference -> { User.count } do
      post user_registration_path(locale: :es), params: {
        user: {
          email: "no-terms@example.com",
          password: "Password123!",
          password_confirmation: "Password123!",
          first_name: "No",
          last_name: "Terms"
        }
      }
    end
    assert_response :unprocessable_content

    assert_difference -> { User.count }, 1 do
      post user_registration_path(locale: :es), params: {
        user: {
          email: "new-buyer@example.com",
          password: "Password123!",
          password_confirmation: "Password123!",
          first_name: "New",
          last_name: "Buyer",
          terms_accepted: "1",
          accepts_marketing: "1"
        }
      }
    end

    user = User.find_by!(email: "new-buyer@example.com")
    assert user.terms_accepted_at.present?
    assert user.accepts_marketing?
    assert_redirected_to root_path(locale: :es)
  end

  test "sign up is refused when registrations are disabled" do
    Setting.set("registrations_enabled", false)

    get new_user_registration_path(locale: :es)

    assert_redirected_to new_user_session_path(locale: :es)
    follow_redirect!
    assert_select "p", text: I18n.t("auth.registrations_disabled")
  ensure
    Setting.set("registrations_enabled", true)
  end

  test "signing in returns to the page that required authentication" do
    get favorites_path(locale: :es)
    assert_redirected_to new_user_session_path(locale: :es)

    post user_session_path(locale: :es), params: {
      user: { email: users(:buyer).email, password: "Password123!" }
    }

    assert_redirected_to favorites_path(locale: :es)
  end

  test "every authentication screen renders with the translated shell" do
    [
      new_user_session_path(locale: :es),
      new_user_registration_path(locale: :es),
      new_user_password_path(locale: :es),
      new_user_confirmation_path(locale: :es),
      new_user_unlock_path(locale: :es)
    ].each do |path|
      get path
      assert_response :success
      assert_select "turbo-frame#auth-modal"
    end
  end
end
