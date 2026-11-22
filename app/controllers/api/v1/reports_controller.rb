module Api
  module V1
    class ReportsController < BaseController
      before_action :authenticate!

      def create
        reportable = reportable_scope.find(params[:reportable_id] || params[:listing_id])
        report = current_user.reports.new(
          reportable: reportable,
          reason: params[:reason],
          details: params[:details].to_s.strip.first(1_000)
        )

        if report.save
          @report = report
          render :create, formats: :json, status: :created
        else
          message = if report.errors.of_kind?(:reportable_id, :taken)
            t("api.errors.report_already_reported")
          else
            t("api.errors.report_failed")
          end
          render_error("validation_failed", message, status: :unprocessable_entity,
                       details: report.errors.to_hash.transform_values { |messages| Array(messages) })
        end
      end

      private

      def reportable_scope
        if params[:reportable_type] == "Conversation"
          Conversation.for_participant(current_user)
        else
          Listing.all
        end
      end
    end
  end
end
