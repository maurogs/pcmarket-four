class FavoritesController < ApplicationController
  before_action :authenticate_user!, except: :create

  def index
    filter = params[:status] == "sold" ? "sold" : "available"
    scope = current_user.favorites
                       .includes(listing: [ :store, :category, :region, :user,
                                            { images_attachments: :blob } ])
                       .order(created_at: :desc)
    scope = if filter == "sold"
      scope.where(listings: { status: Listing.statuses[:sold] })
    else
      scope.where(listings: { status: Listing.statuses[:published] })
    end

    @filter = filter
    @favorites = scope.to_a
    @favorite_ids_by_listing = @favorites.to_h { |favorite| [ favorite.listing_id, favorite.id ] }
    @favorited_listing_ids = @favorite_ids_by_listing.keys.to_set
  end

  def create
    listing = Listing.where(status: [ :published, :sold ]).find(params[:listing_id])

    unless user_signed_in?
      session[:pending_favorite_id] = listing.id
      store_location_for(:user, request.referer)
      redirect_to new_user_session_path, notice: t("favorites.login_required") and return
    end

    current_user.favorites.find_or_create_by!(listing: listing)
    respond_to_favorite(listing, favorited: true)
  end

  def destroy
    favorite = current_user.favorites.find(params[:id])
    listing = favorite.listing
    favorite.destroy!

    respond_to_favorite(listing, favorited: false)
  end

  private

  def respond_to_favorite(listing, favorited:)
    count = Favorite.where(listing_id: listing.id).count
    favorite = favorited ? current_user.favorites.find_by(listing_id: listing.id) : nil

    respond_to do |format|
      format.turbo_stream do
        streams = [
          turbo_stream.replace_all(
            ".js-favorite-#{listing.id}",
            partial: "favorites/button",
            locals: { listing: listing, favorited: favorited, favorite_id: favorite&.id }
          ),
          turbo_stream.replace(
            "favorite-count-#{listing.id}",
            partial: "favorites/count",
            locals: { listing: listing, count: count }
          )
        ]
        streams << turbo_stream.remove("favorite-card-#{listing.id}") unless favorited
        render turbo_stream: streams
      end
      format.html do
        redirect_back fallback_location: listing_path(listing),
                    notice: t(favorited ? "favorites.added" : "favorites.removed")
      end
    end
  end
end
