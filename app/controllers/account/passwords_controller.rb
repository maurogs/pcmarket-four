module Account
  class PasswordsController < BaseController
    def edit
    end

    def update
      if current_password_required? && !current_user.valid_password?(params[:current_password].to_s)
        flash.now[:alert] = t("account.password.wrong_current")
        render :edit, status: :unprocessable_entity
        return
      end

      if current_user.update(password_params)
        bypass_sign_in(current_user)
        redirect_to account_password_path, notice: t("account.password.saved")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def current_password_required?
      !current_user.oauth_only?
    end

    def password_params
      params.require(:user).permit(:password, :password_confirmation)
    end
  end
end
