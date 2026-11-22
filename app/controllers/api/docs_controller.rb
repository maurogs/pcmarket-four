module Api
  class DocsController < ActionController::Base
    layout false

    def show
      path = Rails.root.join("docs/api/openapi.yaml")
      @spec = YAML.safe_load(path.read, aliases: true)
      @groups = @spec.fetch("paths", {}).group_by do |path, operations|
        operations.values.filter_map { |operation| Array(operation["tags"]).first }.first || "Other"
      end
      @title = @spec.dig("info", "title") || "API documentation"

      render :show, formats: :html
    rescue Psych::SyntaxError, Errno::ENOENT
      render plain: "OpenAPI specification unavailable", status: :service_unavailable
    end
  end
end
