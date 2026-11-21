module Admin
  class ImpersonationsController < BaseController
    skip_before_action :require_staff, only: :destroy

    def create
      user = User.find(params[:user_id])
      authorize_admin!(user, :impersonate?)

      AdminAuditLog.create!(
        admin: current_user,
        action: "user.impersonated",
        auditable: user,
        changeset: { "admin_id" => current_user.id, "user_id" => user.id },
        ip: request.remote_ip
      )
      session[:impersonator_id] = current_user.id
      impersonated_locale = user.locale
      sign_in(:user, user)
      redirect_to root_path(locale: impersonated_locale),
                  notice: t("admin.impersonation.started", name: user.display_name)
    end

    def destroy
      admin = current_impersonator
      unless admin&.admin?
        redirect_to root_path, alert: t("admin.impersonation.not_impersonating")
        return
      end

      AdminAuditLog.create!(
        admin: admin,
        action: "user.impersonation_stopped",
        auditable: current_user,
        changeset: { "admin_id" => admin.id, "user_id" => current_user.id },
        ip: request.remote_ip
      )
      session.delete(:impersonator_id)
      sign_in(:user, admin)
      redirect_to admin_root_path, notice: t("admin.impersonation.stopped")
    end
  end
end
