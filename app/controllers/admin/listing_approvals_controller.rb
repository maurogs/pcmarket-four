module Admin
  class ListingApprovalsController < BaseController
    def create
      listing = Listing.friendly.find(params[:listing_id])
      authorize_admin!(listing, :approve?)

      if Admin::ListingModeration.approve(listing, current_user)
        if params[:feature_days].to_i.positive?
          Admin::ListingModeration.feature(listing, params[:feature_days].to_i)
        end
        audit!("listing.approved", listing)
        redirect_back_or_to admin_moderation_queue_path,
                            notice: t("admin.moderation.approved", title: listing.title)
      else
        redirect_back_or_to admin_moderation_queue_path,
                            alert: t("admin.moderation.cannot_approve")
      end
    end
  end
end
