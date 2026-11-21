module Account
  class FollowingController < BaseController
    def index
      @stores = current_user.followed_stores
                          .includes(:user, { listings: [ { images_attachments: :blob } ] })
                          .order("stores.updated_at DESC")
      @latest_listings = Listing.visible
                                .where(store_id: @stores.select(:id))
                                .includes(:store, :user, :category, images_attachments: :blob)
                                .order(published_at: :desc)
                                .limit(24)
    end
  end
end
