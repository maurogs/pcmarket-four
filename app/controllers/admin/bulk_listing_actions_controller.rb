module Admin
  class BulkListingActionsController < BaseController
    def create
      authorize_admin!(Listing, :bulk?)
      authorize_admin!(Listing, :destroy?) if params[:bulk_action].to_s == "delete"

      service = Admin::BulkListingAction.new(
        admin: current_user,
        ids: params[:listing_ids],
        action: params[:bulk_action],
        label: params[:label],
        days: params[:days],
        reason: params[:reason].presence
      )
      processed = service.call

      processed.each do |listing|
        audit!("listing.bulk_#{params[:bulk_action]}", listing,
               changeset: { "action" => params[:bulk_action], "label" => params[:label] })
      end

      redirect_back_or_to admin_listings_path,
                          notice: t("admin.listings.bulk_done", count: processed.size)
    end
  end
end
