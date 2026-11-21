module Admin
  class UserBansController < BaseController
    def create
      user = User.find(params[:user_id])
      authorize_admin!(user, :ban?)

      Admin::UserModeration.ban(user, reason: params[:reason])
      audit!("user.banned", user, changeset: { "status" => [ "active", "banned" ],
                                               "reason" => params[:reason] })
      redirect_back_or_to admin_user_path(user), notice: t("admin.users.banned")
    end

    def destroy
      user = User.find(params[:user_id])
      authorize_admin!(user, :unban?)

      Admin::UserModeration.unban(user)
      audit!("user.unbanned", user, changeset: { "status" => [ "banned", "active" ] })
      redirect_back_or_to admin_user_path(user), notice: t("admin.users.unbanned")
    end
  end
end
