require "test_helper"

module Api
  module V1
    class AuthTest < ActionDispatch::IntegrationTest
      include ApiTestHelper

      setup do
        @buyer = users(:buyer)
        @google_env = ENV.to_hash.slice("GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_IDS")
        ENV.delete("GOOGLE_CLIENT_ID")
        ENV.delete("GOOGLE_CLIENT_IDS")
      end

      teardown do
        ENV.delete("GOOGLE_CLIENT_ID")
        ENV.delete("GOOGLE_CLIENT_IDS")
        @google_env.each { |key, value| ENV[key] = value }
      end

      test "signs in and returns a token stored only as a digest" do
        post "/api/v1/auth/sessions",
             params: { email: @buyer.email, password: "Password123!" }, as: :json

        assert_response :created
        assert json_body.dig("data", "token").present?
        assert_equal "Bearer", json_body.dig("data", "token_type")
        assert_equal @buyer.id, json_body.dig("data", "user", "id")

        raw = json_body.dig("data", "token")
        token = ApiToken.order(:id).last
        assert_equal Digest::SHA256.hexdigest(raw), token.token_digest
        assert_nil token.token
        assert_in_delta 90.days.from_now, token.expires_at, 1.minute
      end

      test "rejects invalid credentials with the error envelope" do
        post "/api/v1/auth/sessions",
             params: { email: @buyer.email, password: "wrong" }, as: :json

        assert_error_envelope 401, "invalid_credentials"
      end

      test "rejects locked accounts" do
        @buyer.update_columns(locked_at: Time.current, failed_attempts: 20)

        post "/api/v1/auth/sessions",
             params: { email: @buyer.email, password: "Password123!" }, as: :json

        assert_error_envelope 403, "account_locked"
      end

      test "rejects unconfirmed accounts" do
        @buyer.update_columns(confirmed_at: nil)

        post "/api/v1/auth/sessions",
             params: { email: @buyer.email, password: "Password123!" }, as: :json

        assert_error_envelope 403, "email_unconfirmed"
      end

      test "rejects suspended accounts" do
        @buyer.update_columns(status: User.statuses[:suspended])

        post "/api/v1/auth/sessions",
             params: { email: @buyer.email, password: "Password123!" }, as: :json

        assert_error_envelope 403, "account_suspended"
      end

      test "rejects expired tokens" do
        token = issue_token_for(@buyer, expires_at: 1.minute.ago)

        api_get "/api/v1/me", token: token

        assert_error_envelope 401, "unauthorized"
      end

      test "revokes the current token" do
        api_delete "/api/v1/auth/sessions"
        assert_response :no_content

        api_get "/api/v1/me"
        assert_error_envelope 401, "unauthorized"
      end

      test "updates last_used_at at most once per hour" do
        token = api_tokens(:buyer_api_token)
        token.update_columns(last_used_at: nil)

        api_get "/api/v1/me"
        assert_response :ok
        token.reload
        first_use = token.last_used_at
        assert first_use.present?

        token.update_columns(last_used_at: 30.minutes.ago)
        api_get "/api/v1/me"
        assert_equal 30.minutes.ago.to_i, token.reload.last_used_at.to_i
      end

      test "signs in with a Google ID token for an iOS client id from the list" do
        ENV["GOOGLE_CLIENT_IDS"] = "web-client-id, ios-client-id"
        stub_google_token(google_token_payload)

        post "/api/v1/auth/google", params: { id_token: "google-token" }, as: :json

        assert_response :ok
        assert json_body.dig("data", "token").present?
        assert User.exists?(email: "new-google@example.com", provider: "google_oauth2")
      end

      test "accepts the legacy GOOGLE_CLIENT_ID configuration" do
        ENV["GOOGLE_CLIENT_ID"] = "legacy-client-id"
        stub_google_token(google_token_payload(aud: "legacy-client-id"))

        post "/api/v1/auth/google", params: { id_token: "google-token" }, as: :json

        assert_response :ok
      end

      test "disables Google sign-in when no client ids are configured" do
        post "/api/v1/auth/google", params: { id_token: "google-token" }, as: :json

        assert_error_envelope 503, "google_sign_in_unavailable"
        assert_not_requested :get, %r{oauth2\.googleapis\.com/tokeninfo}
      end

      test "rejects a Google token with an unknown audience" do
        ENV["GOOGLE_CLIENT_IDS"] = "web-client-id,ios-client-id"
        stub_google_token(google_token_payload(aud: "other-client-id"))

        post "/api/v1/auth/google", params: { id_token: "google-token" }, as: :json

        assert_error_envelope 401, "google_invalid_token"
      end

      test "rejects a Google token with an unverified email" do
        ENV["GOOGLE_CLIENT_IDS"] = "web-client-id,ios-client-id"
        stub_google_token(google_token_payload(email_verified: false))

        post "/api/v1/auth/google", params: { id_token: "google-token" }, as: :json

        assert_error_envelope 401, "google_invalid_token"
      end

      test "rejects a Google token with a bad issuer" do
        ENV["GOOGLE_CLIENT_IDS"] = "web-client-id,ios-client-id"
        stub_google_token(google_token_payload(iss: "https://evil.example.com"))

        post "/api/v1/auth/google", params: { id_token: "google-token" }, as: :json

        assert_error_envelope 401, "google_invalid_token"
      end

      test "rejects an expired Google token" do
        ENV["GOOGLE_CLIENT_IDS"] = "web-client-id,ios-client-id"
        stub_google_token(google_token_payload(exp: 1.minute.ago.to_i))

        post "/api/v1/auth/google", params: { id_token: "google-token" }, as: :json

        assert_error_envelope 401, "google_invalid_token"
      end

      test "rejects an invalid Google token" do
        ENV["GOOGLE_CLIENT_IDS"] = "web-client-id,ios-client-id"
        stub_request(:get, %r{oauth2\.googleapis\.com/tokeninfo})
          .to_return(status: 400, body: "{}")

        post "/api/v1/auth/google", params: { id_token: "bad" }, as: :json

        assert_error_envelope 401, "google_invalid_token"
      end

      test "respects registrations_enabled and terms acceptance" do
        Setting.set("registrations_enabled", false)
        post "/api/v1/auth/registrations",
             params: { email: "new@example.com", password: "Password123!",
                       terms_accepted: true }, as: :json
        assert_error_envelope 403, "registrations_disabled"

        Setting.set("registrations_enabled", true)
        post "/api/v1/auth/registrations",
             params: { email: "new@example.com", password: "Password123!" }, as: :json
        assert_error_envelope 422, "validation_failed"

        post "/api/v1/auth/registrations",
             params: { email: "new@example.com", password: "Password123!",
                       terms_accepted: true, first_name: "New" }, as: :json

        assert_response :created
        assert_equal "new@example.com", json_body.dig("data", "email")
      end

      test "requests password reset instructions without leaking accounts" do
        post "/api/v1/auth/passwords", params: { email: @buyer.email }, as: :json
        assert_response :accepted

        post "/api/v1/auth/passwords", params: { email: "missing@example.com" }, as: :json
        assert_response :accepted
      end

      private

      def google_token_payload(overrides = {})
        {
          sub: "google-123",
          email: "new-google@example.com",
          given_name: "New",
          family_name: "Google",
          aud: "ios-client-id",
          iss: "accounts.google.com",
          email_verified: "true",
          exp: 1.hour.from_now.to_i
        }.merge(overrides)
      end

      def stub_google_token(payload, token: "google-token")
        stub_request(:get, %r{oauth2\.googleapis\.com/tokeninfo})
          .with(query: hash_including("id_token" => token))
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: payload.to_json
          )
      end
    end
  end
end
