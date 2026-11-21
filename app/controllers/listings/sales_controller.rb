module Listings
  class SalesController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_active_account
    before_action :set_listing

    def create
      authorize @listing, :update?

      if @listing.mark_sold!
        redirect_to seller_listings_path, notice: t("listings.flash.marked_sold")
      else
        redirect_to seller_listings_path, alert: t("listings.flash.cannot_mark_sold")
      end
    end

    private

    def ensure_active_account
      return if current_user.nil? || current_user.active_account?

      redirect_to root_path, alert: t("errors.account_inactive")
    end

    def set_listing
      @listing = current_user.listings.find_by(slug: params[:listing_id])
      raise ActiveRecord::RecordNotFound if @listing.nil?
    end
  end
end
