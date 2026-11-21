module Seller
  class FeatureRequestsController < BaseController
    before_action :require_featured_enabled

    def new
      @listing = seller_store.listings.find(params[:listing_id])
      @price_cents = Setting.get("featured_price_cents", 499).to_i
      @days = 7
      @pending_request = FeatureRequest.pending.find_by(listing: @listing, user: current_user)
    end

    def create
      @listing = seller_store.listings.find(params[:listing_id])
      request = FeatureRequest.new(
        listing: @listing,
        user: current_user,
        days: 7,
        price_cents: Setting.get("featured_price_cents", 499).to_i,
        status: :pending
      )
      if request.save
        redirect_to seller_listings_path, notice: t("seller.feature_requests.created")
      else
        redirect_to seller_listings_path, alert: t("seller.feature_requests.invalid")
      end
    end

    private

    def require_featured_enabled
      return if Setting.enabled?("featured_listings_enabled")

      redirect_to seller_listings_path, alert: t("seller.feature_requests.disabled")
    end
  end
end
