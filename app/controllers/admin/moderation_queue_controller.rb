module Admin
  class ModerationQueueController < BaseController
    QUEUE_LIMIT = 10

    def index
      authorize_admin!(:moderation_queue, :index?)

      @pagy, @listings = pagy(
        Listing.pending_review
               .includes(:user, :store, :category, images_attachments: :blob)
               .order(created_at: :asc),
        limit: QUEUE_LIMIT
      )
      @flags = @listings.index_with { |listing| Admin::ListingFlags.call(listing) }
    end
  end
end
