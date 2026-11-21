module Admin
  class ReportsController < BaseController
    before_action :set_report, only: %i[show update]

    def index
      authorize_admin!(Report, :index?)

      @query = Admin::ReportQuery.new(filter_params)
      @reports = @query.call
      @counts = @query.counts
      @pagy, @reports = pagy(@reports, limit: pagination_limit)
    end

    def show
      authorize_admin!(@report, :show?)
      @other_reports = Report.where(reportable: @report.reportable).where.not(id: @report.id)
                             .includes(:reporter).order(created_at: :desc)
      @audit_logs = AdminAuditLog.where(auditable: @report.reportable).includes(:admin).recent.limit(10)
    end

    def update
      authorize_admin!(@report, :resolve?)

      action = params.dig(:report, :action).to_s
      authorize_admin!(@report, :delete_review?) if action == "delete_review"

      resolution = Admin::ReportResolution.new(
        current_user, @report,
        decision: params.dig(:report, :decision),
        action: action,
        reason: params.dig(:report, :reason)
      )

      if resolution.call
        audit!("report.#{@report.status}", @report,
               changeset: { "status" => [ "open", @report.status ], "action" => action })
        redirect_to admin_reports_path, notice: t("admin.reports.updated")
      else
        redirect_to admin_report_path(@report), alert: t("admin.reports.cannot_resolve")
      end
    end

    private

    def set_report
      @report = Report.includes(:reporter, :reportable).find(params[:id])
    end

    def filter_params
      params.permit(:status, :reason, :reportable_type, :sort, :direction)
    end
  end
end
