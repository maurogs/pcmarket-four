require "test_helper"
require "yaml"

module Api
  module V1
    class DocsTest < ActionDispatch::IntegrationTest
      include ApiTestHelper

      test "serves the OpenAPI document as YAML" do
        api_get "/api/v1/openapi.yaml", token: nil

        assert_response :ok
        assert_includes response.media_type, "yaml"
        spec = YAML.safe_load(response.body, aliases: true)
        assert_equal "3.1.0", spec["openapi"]
        assert_equal "PCMarket API", spec.dig("info", "title")
      end

      test "documents every API v1 route path" do
        spec = YAML.safe_load(Rails.root.join("docs/api/openapi.yaml").read, aliases: true)
        documented = spec.fetch("paths").keys.map { |path| normalize(path) }.to_set

        actual = Rails.application.routes.routes.filter_map do |route|
          path = route.path.spec.to_s.sub("(.:format)", "")
          normalize(path) if path.start_with?("/api/v1")
        end.to_set

        assert_empty actual - documented, "Missing paths in docs/api/openapi.yaml"
      end

      test "declares the core schemas" do
        spec = YAML.safe_load(Rails.root.join("docs/api/openapi.yaml").read, aliases: true)
        schemas = spec.fetch("components").fetch("schemas").keys

        %w[Listing Category Store Order Conversation Message Error Pagination].each do |name|
          assert_includes schemas, name
        end
        assert spec.dig("components", "securitySchemes", "bearerAuth")
      end

      test "renders the human documentation page without external assets" do
        get "/api/docs"

        assert_response :ok
        assert_includes response.body, "PCMarket API"
        assert_includes response.body, "/api/v1/listings"
        assert_not_includes response.body, "cdn."
      end

      private

      def normalize(path)
        path.gsub(/:([a-z_]+)/) { "{#{Regexp.last_match(1)}}" }
      end
    end
  end
end
