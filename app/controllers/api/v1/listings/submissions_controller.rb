module Api
  module V1
    module Listings
      class SubmissionsController < BaseController
        before_action :authenticate!
        before_action :set_listing

        def create
          authorize @listing, :update?

          unless @listing.submit_for_review!
            return render_error("order_action_failed", t("api.errors.order_action_failed"),
                                status: :conflict)
          end

          render "api/v1/listings/show", formats: :json, status: :accepted
        end

        private

        def set_listing
          @listing = current_user.listings.friendly.find(params[:listing_slug])
        end
      end
    end
  end
end
