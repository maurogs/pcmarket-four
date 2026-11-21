module Account
  class DeletionsController < BaseController
    def new
    end

    def create
      unless deletion_confirmed?
        flash.now[:alert] = t("account.deletion.confirmation_error")
        render :new, status: :unprocessable_entity
        return
      end

      current_user.soft_delete!
      sign_out(current_user)
      redirect_to root_path, notice: t("account.deletion.done")
    end

    private

    def deletion_confirmed?
      if current_user.oauth_only?
        params[:confirmation].to_s == "DELETE"
      else
        current_user.valid_password?(params[:current_password].to_s)
      end
    end
  end
end
