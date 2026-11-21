module Admin
  class UserSuspensionsController < BaseController
    def create
      user = User.find(params[:user_id])
      authorize_admin!(user, :suspend?)

      Admin::UserModeration.suspend(user, reason: params[:reason])
      audit!("user.suspended", user, changeset: { "status" => [ "active", "suspended" ],
                                                  "reason" => params[:reason] })
      redirect_back_or_to admin_user_path(user), notice: t("admin.users.suspended")
    end

    def destroy
      user = User.find(params[:user_id])
      authorize_admin!(user, :unsuspend?)

      Admin::UserModeration.unsuspend(user)
      audit!("user.unsuspended", user, changeset: { "status" => [ "suspended", "active" ] })
      redirect_back_or_to admin_user_path(user), notice: t("admin.users.unsuspended")
    end
  end
end
