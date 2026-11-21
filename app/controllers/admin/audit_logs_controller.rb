module Admin
  class AuditLogsController < BaseController
    def index
      authorize_admin!(:audit_log, :index?)

      scope = AdminAuditLog.includes(:admin, :auditable).recent
      scope = scope.where("action LIKE ?", "#{AdminAuditLog.sanitize_sql_like(params[:action_filter].to_s)}%") if params[:action_filter].present?
      scope = scope.where(admin_id: params[:admin_id]) if params[:admin_id].present?
      scope = scope.where(auditable_type: params[:auditable_type]) if params[:auditable_type].present?

      @pagy, @audit_logs = pagy(scope, limit: pagination_limit)
      @admins = User.staff.order(:username)
      @actions = AdminAuditLog.distinct.order(:action).pluck(:action)
    end
  end
end
