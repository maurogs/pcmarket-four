class ReportsController < ApplicationController
  before_action :authenticate_user!

  def create
    listing = Listing.find(params[:listing_id])
    report = current_user.reports.new(
      reportable: listing,
      reason: params[:reason],
      details: params[:details].to_s.strip.first(1_000)
    )

    if report.save
      redirect_back fallback_location: listing_path(listing), notice: t("reports.created")
    else
      message = if report.errors.of_kind?(:reportable_id, :taken)
        t("reports.already_reported")
      else
        t("reports.invalid")
      end
      redirect_back fallback_location: listing_path(listing), alert: message
    end
  end
end
