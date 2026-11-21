module Seller
  class BulkListingActionsController < ApplicationController
    before_action :authenticate_user!

    def create
      action = (params[:bulk_action].presence || params[:action]).to_s
      count = BulkListingAction.new(
        user: current_user,
        ids: params[:listing_ids],
        action: action
      ).call

      if count.positive?
        redirect_to seller_listings_path, notice: t("listings.seller.bulk_done", count: count)
      else
        redirect_to seller_listings_path, alert: t("listings.seller.bulk_none")
      end
    end
  end
end
