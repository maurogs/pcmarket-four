module Api
  module V1
    module Listings
      class ImagesController < BaseController
        before_action :authenticate!
        before_action :set_listing

        def create
          items = Array(params[:images]).compact_blank
          items = Array(params[:signed_id]).compact_blank if items.empty?
          raise ActionController::ParameterMissing, :images if items.empty?

          limit = Setting.get("max_images_per_listing", 12).to_i
          if @listing.images.attachments.size + items.size > limit
            return render_error("image_limit", t("api.errors.image_limit"), status: :unprocessable_entity)
          end

          @listing.images.attach(items)
          reindex_images!
          @listing.save!

          render "api/v1/listings/images/index", formats: :json, status: :created
        end

        def destroy
          attachment = @listing.images.attachments.find(params[:id])
          attachment.purge
          head :no_content
        end

        def positions
          order = params[:image_ids] || params[:positions]
          ids = order.respond_to?(:to_h) ? order.to_h.keys : Array(order)
          position_map = ids.each_with_index.to_h { |id, index| [ id.to_i, index ] }

          @listing.images.attachments.each do |attachment|
            next unless position_map.key?(attachment.id)

            attachment.blob.update!(metadata: attachment.blob.metadata.merge("position" => position_map[attachment.id]))
          end

          @listing.images.reset
          render "api/v1/listings/images/index", formats: :json
        end

        private

        def set_listing
          @listing = current_user.listings.friendly.find(params[:listing_slug])
          authorize @listing, :update?
        end

        def reindex_images!
          @listing.images.attachments.each_with_index do |attachment, index|
            next if attachment.blob.metadata["position"].present?

            attachment.blob.update!(metadata: attachment.blob.metadata.merge("position" => index))
          end
        end
      end
    end
  end
end
