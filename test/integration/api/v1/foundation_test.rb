require "test_helper"

module Api
  module V1
    class FoundationTest < ActionDispatch::IntegrationTest
      include ApiTestHelper

      setup do
        @buyer = users(:buyer)
        @admin = users(:admin)
      end

      test "returns the success envelope on config" do
        api_get "/api/v1/config", token: nil

        assert_response :ok
        assert json_body.key?("data")
        assert json_body.key?("meta")
        data = json_body["data"]
        assert_equal "PCMarket", data["site_name"]
        assert_includes data["locales"], "es"
        assert_equal "1.0.0", data["min_app_version"]
        assert data["feature_flags"].key?("checkout_enabled")
        assert data["countries"].any?
        assert data["payment_methods"].any?
      end

      test "translates names with the Accept-Language header" do
        api_get "/api/v1/config", token: nil, headers: { "Accept-Language" => "en-GB,en;q=0.9" }

        condition = json_body["data"]["listing_conditions"].find { |item| item["key"] == "new_sealed" }
        assert_equal "New sealed", condition["name"]
      end

      test "validates the locale param and falls back to Spanish" do
        api_get "/api/v1/config?locale=fr", token: nil
        condition = json_body["data"]["listing_conditions"].find { |item| item["key"] == "new_sealed" }
        assert_equal "Neuf scellé", condition["name"]

        api_get "/api/v1/config?locale=xx", token: nil
        condition = json_body["data"]["listing_conditions"].find { |item| item["key"] == "new_sealed" }
        assert_equal "Nuevo precintado", condition["name"]
      end

      test "renders a translated error envelope for missing resources" do
        api_get "/api/v1/listings/does-not-exist", token: nil

        assert_error_envelope 404, "not_found"
        assert_equal I18n.t("api.errors.not_found", locale: :es), json_body.dig("error", "message")
      end

      test "rejects authenticated endpoints without a token" do
        api_get "/api/v1/me", token: nil

        assert_error_envelope 401, "unauthorized"
      end

      test "returns 503 in maintenance mode for non-staff" do
        Setting.set("maintenance_mode", true)

        api_get "/api/v1/config", token: nil
        assert_error_envelope 503, "maintenance"

        api_get "/api/v1/config"
        assert_response :service_unavailable

        admin_token = issue_token_for(@admin)
        api_get "/api/v1/config", token: admin_token
        assert_response :ok
      end

      test "adds CORS headers for configured origins" do
        ENV["API_CORS_ORIGINS"] = "https://app.example, https://admin.example"

        api_get "/api/v1/config", token: nil, headers: { "Origin" => "https://app.example" }
        assert_equal "https://app.example", response.headers["Access-Control-Allow-Origin"]

        api_get "/api/v1/config", token: nil, headers: { "Origin" => "https://evil.example" }
        assert_nil response.headers["Access-Control-Allow-Origin"]
      ensure
        ENV.delete("API_CORS_ORIGINS")
      end

      test "throttles login attempts per IP" do
        Rack::Attack.enabled = true
        Rack::Attack.reset!

        11.times do
          post "/api/v1/auth/sessions",
               params: { email: "throttled@example.com", password: "wrong" }, as: :json
        end

        assert_error_envelope 429, "rate_limited"
      end

      test "supports conditional GET with ETag and public caching" do
        api_get "/api/v1/listings", token: nil
        assert_response :ok
        etag = response.headers["ETag"]
        assert etag.present?
        assert_match(/public/, response.headers["Cache-Control"])

        get "/api/v1/listings", headers: { "If-None-Match" => etag }
        assert_response :not_modified
      end
    end
  end
end
