module Api
  module V1
    module Auth
      class GoogleController < BaseController
        def create
          user = GoogleSignIn.new(params[:id_token]).call
          @user = user
          @token = ApiToken.issue!(user: user, name: params[:device_name])
          render "api/v1/auth/sessions/create", formats: :json, status: :ok
        rescue GoogleTokenVerifier::Error => error
          if error.message == "not_configured"
            return render_error("google_sign_in_unavailable",
                                t("api.errors.google_sign_in_unavailable"),
                                status: :service_unavailable)
          end

          render_error("google_invalid_token", t("api.errors.google_invalid_token"),
                       status: :unauthorized)
        rescue GoogleSignIn::Error => error
          if error.message == "suspended"
            return render_error("account_suspended", t("api.errors.account_suspended"),
                                status: :forbidden)
          end

          render_error("google_invalid_token", t("api.errors.google_invalid_token"),
                       status: :unauthorized)
        rescue ActiveRecord::RecordInvalid
          render_error("validation_failed", t("api.errors.validation_failed"),
                       status: :unprocessable_entity)
        end
      end
    end
  end
end
