module Api
  module V1
    class BaseController < ActionController::API
      include Pundit::Authorization
      include ActionController::HttpAuthentication::Token
      include ActionController::HttpAuthentication::Token::ControllerMethods
      include ActionController::Helpers
      include AbstractController::Translation
      include Api::V1::SerializationHelper

      helper Api::V1::SerializationHelper
      helper_method :current_user

      around_action :switch_locale
      before_action :load_current_token
      before_action :enforce_maintenance_mode
      before_action :enforce_terms_acceptance

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from Pundit::NotAuthorizedError, with: :render_forbidden
      rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
      rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
      rescue_from ActiveRecord::RecordNotUnique, with: :render_record_invalid
      rescue_from ActionController::BadRequest, with: :render_bad_request

      attr_reader :current_api_token

      def current_user
        @current_user
      end

      def pundit_user
        current_user
      end

      private

      def authenticate!
        return true if current_user.present?

        render_error("unauthorized", t("api.errors.unauthorized"), status: :unauthorized)
        false
      end

      def load_current_token
        @current_api_token = ApiToken.authenticate(bearer_token)
        @current_user = @current_api_token&.user
        return if @current_user.blank?

        unless @current_user.active_account?
          @current_api_token = nil
          @current_user = nil
          return
        end

        @current_api_token.touch_last_used!
      end

      def bearer_token
        authenticate_with_http_token { |token, _options| return token }
        request.headers["X-Api-Token"].presence
      end

      def switch_locale(&action)
        I18n.with_locale(requested_locale, &action)
      end

      def requested_locale
        candidate = params[:locale].presence || locale_from_header
        candidate = candidate.to_s.downcase
        I18n.available_locales.map(&:to_s).include?(candidate) ? candidate : I18n.default_locale.to_s
      end

      def locale_from_header
        header = request.headers["Accept-Language"].to_s
        header.split(",").filter_map do |part|
          tag, quality = part.strip.split(";")
          next if quality.present? && quality.delete("q=").to_f.zero?

          tag.to_s.split("-").first.presence
        end.first
      end

      def enforce_maintenance_mode
        return unless Setting.enabled?("maintenance_mode")
        return if current_user&.staff?

        render_error("maintenance", t("api.errors.maintenance"), status: :service_unavailable)
      end

      def enforce_terms_acceptance
        return if current_user.blank? || current_user.terms_accepted_at.present?
        return if terms_acceptance_endpoint?

        render_error("terms_not_accepted", t("api.errors.terms_not_accepted"), status: :forbidden)
      end

      def terms_acceptance_endpoint?
        controller_path == "api/v1/me/terms_acceptances" ||
          controller_path.start_with?("api/v1/legal_pages", "api/v1/config")
      end

      def render_error(code, message, status:, details: {})
        @error_code = code
        @error_message = message
        @error_details = details.presence || {}
        render partial: "api/v1/shared/error", formats: :json, status: status
      end

      def render_not_found
        render_error("not_found", t("api.errors.not_found"), status: :not_found)
      end

      def render_forbidden
        render_error("forbidden", t("api.errors.forbidden"), status: :forbidden)
      end

      def render_parameter_missing(error)
        render_error("bad_request", t("api.errors.bad_request"), status: :bad_request,
                     details: { error.param.to_s => [ t("api.errors.bad_request") ] })
      end

      def render_bad_request
        render_error("bad_request", t("api.errors.bad_request"), status: :bad_request)
      end

      def render_record_invalid(error)
        record = error.respond_to?(:record) ? error.record : nil
        details = record ? record.errors.to_hash.transform_values { |messages| Array(messages) } : {}

        render_error("validation_failed", t("api.errors.validation_failed"),
                     status: :unprocessable_entity, details: details)
      end

      def pagination_meta(pagy)
        {
          page: pagy.page,
          per_page: pagy.limit,
          total: pagy.count,
          total_pages: pagy.pages
        }
      end

      def paginate(scope, default: Api::Pagination::DEFAULT_PER_PAGE)
        result = Api::Pagination.call(scope, params: params, default: default)
        [ result.records, result.pagy ]
      end

      def cache_public_read!(record = nil, extra: nil)
        return if current_user.present?

        expires_in 60.seconds, public: true
        fresh_when(etag: [ I18n.locale, extra, record, Listing.maximum(:updated_at) ], public: true)
      end

      def truthy?(value)
        ActiveModel::Type::Boolean.new.cast(value) == true
      end
    end
  end
end
