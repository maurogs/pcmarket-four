module Api
  module V1
    module Auth
      class SessionsController < BaseController
        before_action :authenticate!, only: :destroy

        def create
          user = User.find_by(email: params[:email].to_s.strip.downcase)

          unless user&.valid_password?(params[:password].to_s)
            return render_error("invalid_credentials", t("api.errors.invalid_credentials"),
                                status: :unauthorized)
          end

          return render_error("account_suspended", t("api.errors.account_suspended"),
                              status: :forbidden) unless user.active_account?
          return render_error("account_locked", t("api.errors.account_locked"),
                              status: :forbidden) if user.access_locked?
          return render_error("email_unconfirmed", t("api.errors.email_unconfirmed"),
                              status: :forbidden) unless user.confirmed?

          @user = user
          @token = ApiToken.issue!(user: user, name: params[:device_name])
          render :create, formats: :json, status: :created
        end

        def destroy
          current_api_token.destroy!
          head :no_content
        end
      end
    end
  end
end
