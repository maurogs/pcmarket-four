class ReportsController < ApplicationController
  before_action :authenticate_user!

  def create
    reportable = reportable_scope.find(reportable_id)
    report = current_user.reports.new(
      reportable: reportable,
      reason: params[:reason],
      details: params[:details].to_s.strip.first(1_000)
    )

    if report.save
      redirect_back fallback_location: fallback_path(reportable), notice: t("reports.created")
    else
      message = if report.errors.of_kind?(:reportable_id, :taken)
        t("reports.already_reported")
      else
        t("reports.invalid")
      end
      redirect_back fallback_location: fallback_path(reportable), alert: message
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

  def reportable_id
    params[:reportable_id].presence || params[:listing_id]
  end

  def fallback_path(reportable)
    reportable.is_a?(Conversation) ? conversation_path(reportable) : listing_path(reportable)
  end
end
