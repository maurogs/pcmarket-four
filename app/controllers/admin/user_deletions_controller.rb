module Admin
  class UserDeletionsController < BaseController
    def create
      user = User.find(params[:user_id])
      authorize_admin!(user, :destroy?)

      user.soft_delete!
      audit!("user.soft_deleted", user, changeset: { "deleted_at" => user.deleted_at,
                                                     "username" => user.username })
      redirect_to admin_users_path, notice: t("admin.users.soft_deleted"), status: :see_other
    end
  end
end
