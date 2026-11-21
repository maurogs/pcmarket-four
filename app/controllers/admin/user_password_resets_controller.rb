module Admin
  class UserPasswordResetsController < BaseController
    def create
      user = User.find(params[:user_id])
      authorize_admin!(user, :send_password_reset?)

      user.send_reset_password_instructions
      audit!("user.password_reset_sent", user)
      redirect_back_or_to admin_user_path(user), notice: t("admin.users.password_reset_sent")
    end
  end
end
