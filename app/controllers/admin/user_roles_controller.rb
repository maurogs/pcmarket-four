module Admin
  class UserRolesController < BaseController
    def update
      user = User.find(params[:user_id])
      authorize_admin!(user, :role?)

      previous = user.role
      Admin::UserModeration.change_role(user, params[:role], actor: current_user)
      audit!("user.role_changed", user, changeset: { "role" => [ previous, user.role ] })
      redirect_back_or_to admin_user_path(user), notice: t("admin.users.role_changed")
    rescue Admin::UserModeration::Error => error
      redirect_back_or_to admin_user_path(user), alert: role_error_message(error)
    end

    private

    def role_error_message(error)
      case error.message
      when "self_change" then t("admin.users.cannot_change_own_role")
      when "last_admin" then t("admin.users.cannot_demote_last_admin")
      else t("admin.users.invalid_role")
      end
    end
  end
end
