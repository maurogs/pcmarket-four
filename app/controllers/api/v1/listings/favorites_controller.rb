module Api
  module V1
    module Listings
      class FavoritesController < BaseController
        before_action :authenticate!
        before_action :set_listing

        def create
          @favorite = current_user.favorites.find_or_create_by!(listing: @listing)
          @listing.reload

          render :create, formats: :json, status: :created
        end

        def destroy
          current_user.favorites.where(listing_id: @listing.id).destroy_all
          @listing.reload
          head :no_content
        end

        private

        def set_listing
          @listing = Listing.where(status: %i[published sold]).friendly.find(params[:listing_slug])
        end
      end
    end
  end
end
