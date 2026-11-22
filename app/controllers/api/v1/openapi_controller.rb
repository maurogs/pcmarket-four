module Api
  module V1
    class OpenapiController < BaseController
      def show
        path = Rails.root.join("docs/api/openapi.yaml")
        response.headers["Cache-Control"] = "public, max-age=300"
        render plain: path.read, content_type: "application/yaml"
      end
    end
  end
end
