require "test_helper"

module Api
  module V1
    class TermsAcceptanceTest < ActionDispatch::IntegrationTest
      include ApiTestHelper

      setup do
        @buyer = users(:buyer)
        @buyer.update_columns(terms_accepted_at: nil)
      end

      test "requires terms acceptance for authenticated API requests" do
        api_get "/api/v1/me"

        assert_error_envelope 403, "terms_not_accepted"
      end

      test "keeps config and legal pages available before acceptance" do
        api_get "/api/v1/config"
        assert_response :ok

        api_get "/api/v1/legal_pages/terms?country=ES"
        assert_response :ok
      end

      test "accepts the terms and unblocks the API" do
        post "/api/v1/me/terms_acceptance",
             params: { terms_accepted: true, accepts_marketing: true },
             headers: api_headers, as: :json

        assert_response :ok
        assert @buyer.reload.terms_accepted_at.present?
        assert @buyer.accepts_marketing?

        api_get "/api/v1/me"
        assert_response :ok
      end

      test "rejects acceptance without the terms flag" do
        post "/api/v1/me/terms_acceptance", params: {}, headers: api_headers, as: :json

        assert_error_envelope 422, "validation_failed"
        assert_nil @buyer.reload.terms_accepted_at
      end
    end
  end
end
