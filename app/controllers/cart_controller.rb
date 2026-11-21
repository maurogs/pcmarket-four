class CartController < ApplicationController
  def show
    @summary = cart_summary
    @recommended = recommended_listings
    @checkout_enabled = Setting.enabled?("checkout_enabled")
  end

  private

  def recommended_listings
    return Listing.none if @summary.category_ids.empty?

    Listing.visible
           .where(category_id: @summary.category_ids)
           .where.not(id: @summary.listing_ids)
           .includes(:store, :category, :region, :user, images_attachments: :blob)
           .order(published_at: :desc)
           .limit(6)
  end
end
