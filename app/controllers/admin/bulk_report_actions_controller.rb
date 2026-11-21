module Admin
  class BulkReportActionsController < BaseController
    def create
      authorize_admin!(Report, :bulk?)

      reports = Report.open.where(id: params[:report_ids]).to_a
      reports.each do |report|
        Admin::ReportResolution.call(current_user, report, decision: "dismiss")
        audit!("report.dismissed", report, changeset: { "status" => [ "open", "dismissed" ] })
      end

      redirect_to admin_reports_path, notice: t("admin.reports.bulk_dismissed", count: reports.size)
    end
  end
end
