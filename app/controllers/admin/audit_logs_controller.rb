module Admin
  class AuditLogsController < BaseController
    def index
      authorize_admin!(:audit_log, :index?)

      @pagy, @audit_logs = pagy(filtered_scope.includes(:admin, :auditable).recent,
                                limit: pagination_limit)
      @admins = User.staff.order(:username)
      @actions = AdminAuditLog.distinct.order(:action).pluck(:action)
      @auditable_types = AdminAuditLog.distinct.order(:auditable_type).pluck(:auditable_type)
    end

    def show
      authorize_admin!(:audit_log, :show?)

      @audit_log = AdminAuditLog.includes(:admin, :auditable).find(params[:id])
    end

    private

    def filtered_scope
      scope = AdminAuditLog.all
      scope = scope.where("action LIKE ?", "#{AdminAuditLog.sanitize_sql_like(params[:action_filter].to_s)}%") if params[:action_filter].present?
      scope = scope.where(admin_id: params[:admin_id]) if params[:admin_id].present?
      scope = scope.where(auditable_type: params[:auditable_type]) if params[:auditable_type].present?
      scope = scope.where("created_at >= ?", date_from.beginning_of_day) if date_from
      scope = scope.where("created_at <= ?", date_to.end_of_day) if date_to
      scope
    end

    def date_from
      @date_from ||= Date.parse(params[:date_from].to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def date_to
      @date_to ||= Date.parse(params[:date_to].to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
