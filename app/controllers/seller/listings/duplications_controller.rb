module Seller
  module Listings
    class DuplicationsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_listing

      def create
        authorize @listing, :update?

        copy = @listing.dup
        copy.assign_attributes(
          slug: nil,
          status: :draft,
          published_at: nil,
          reviewed_at: nil,
          reviewed_by_id: nil,
          rejection_reason: nil,
          featured_until: nil,
          performance_score: nil,
          views_count: 0,
          favorites_count: 0
        )
        copy.save!

        @listing.images.blobs.each do |blob|
          copy.images.attach(blob.signed_id)
        end

        redirect_to edit_listing_path(copy), notice: t("listings.flash.duplicated")
      end

      private

      def set_listing
        @listing = current_user.listings.find_by(slug: params[:listing_id])
        raise ActiveRecord::RecordNotFound if @listing.nil?
      end
    end
  end
end
