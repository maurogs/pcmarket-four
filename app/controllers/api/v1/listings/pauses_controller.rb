module Api
  module V1
    module Listings
      class PausesController < BaseController
        before_action :authenticate!
        before_action :set_listing

        def create
          authorize @listing, :update?
          return unless transition! { @listing.pause! }

          render "api/v1/listings/show", formats: :json
        end

        def destroy
          authorize @listing, :update?
          return unless transition! { @listing.resume! }

          render "api/v1/listings/show", formats: :json
        end

        private

        def set_listing
          @listing = current_user.listings.friendly.find(params[:listing_slug])
        end

        def transition!
          unless yield
            render_error("order_action_failed", t("api.errors.order_action_failed"), status: :conflict)
            return false
          end

          true
        end
      end
    end
  end
end
