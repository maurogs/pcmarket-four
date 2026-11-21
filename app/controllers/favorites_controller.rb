class FavoritesController < ApplicationController
  before_action :authenticate_user!

  def index
    @favorites = current_user.favorites.includes(:listing).order(created_at: :desc)
  end

  def create
    listing = Listing.find(params[:listing_id])
    current_user.favorites.find_or_create_by!(listing: listing)

    redirect_back fallback_location: listing_path(listing)
  end

  def destroy
    favorite = current_user.favorites.find(params[:id])
    listing = favorite.listing
    favorite.destroy!

    redirect_back fallback_location: listing_path(listing)
  end
end
