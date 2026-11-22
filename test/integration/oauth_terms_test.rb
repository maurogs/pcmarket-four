require "test_helper"

class OauthTermsTest < ActionDispatch::IntegrationTest
  test "rejects an unverified Google email without linking or creating" do
    auth = omniauth_auth(email: users(:buyer).email, verified: false, uid: "google-unverified")

    assert_no_difference -> { User.count } do
      get user_google_oauth2_omniauth_callback_path, env: { "omniauth.auth" => auth }
    end

    assert_redirected_to new_user_session_path(locale: :es)
    follow_redirect!
    assert_equal I18n.t("errors.omniauth_email_unverified", locale: :es), flash[:alert]
    assert_nil users(:buyer).reload.uid
  end

  test "verified Google users are created without terms and sent to acceptance" do
    auth = omniauth_auth(email: "new-oauth@example.com", verified: true, uid: "google-verified")

    assert_difference -> { User.count }, 1 do
      get user_google_oauth2_omniauth_callback_path, env: { "omniauth.auth" => auth }
    end

    user = User.find_by!(email: "new-oauth@example.com")
    assert user.confirmed?
    assert_nil user.terms_accepted_at
    assert_redirected_to new_terms_acceptance_path(locale: :es)

    follow_redirect!
    assert_response :success
    assert_select "input#terms_accepted[required]"
    assert_select "input#accepts_marketing"
    assert_select "a[href='#{legal_page_path('terms', locale: :es)}']"
    assert_select "a[href='#{legal_page_path('privacy', locale: :es)}']"
  end

  test "accepting the terms records the timestamp and unlocks the account" do
    user = User.create!(
      email: "pending-terms@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      first_name: "Pending",
      last_name: "Terms",
      confirmed_at: Time.current
    )
    post user_session_path(locale: :es),
         params: { user: { email: user.email, password: "Password123!" } }

    get root_path(locale: :es)
    assert_redirected_to new_terms_acceptance_path(locale: :es)

    get new_terms_acceptance_path(locale: :es)
    assert_response :success

    post terms_acceptance_path(locale: :es),
         params: { terms_accepted: "1", accepts_marketing: "1" }

    assert_redirected_to root_path(locale: :es)
    user.reload
    assert user.terms_accepted_at.present?
    assert user.accepts_marketing?

    get root_path(locale: :es)
    assert_response :success
  end

  test "refuses acceptance without the terms checkbox" do
    user = User.create!(
      email: "no-acceptance@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      confirmed_at: Time.current
    )
    post user_session_path(locale: :es),
         params: { user: { email: user.email, password: "Password123!" } }

    post terms_acceptance_path(locale: :es), params: { accepts_marketing: "1" }

    assert_redirected_to new_terms_acceptance_path(locale: :es)
    assert_nil user.reload.terms_accepted_at
  end

  private

  def omniauth_auth(email:, verified:, uid:)
    OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: { email: email, first_name: "New", last_name: "OAuth" },
      extra: { raw_info: { email_verified: verified } }
    )
  end
end
