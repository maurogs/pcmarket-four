module Api
  module V1
    module Me
      class FavoritesController < BaseController
        before_action :authenticate!

        def index
          status = params[:status] == "sold" ? "sold" : "published"
          scope = current_user.favorites
                             .joins(:listing)
                             .where(listings: { status: Listing.statuses[status] })
                             .includes(listing: [ :store, :category, :region, :user,
                                                  { images_attachments: :blob } ])
                             .order(created_at: :desc)
          @favorites, @pagy = paginate(scope)
          render :index, formats: :json
        end
      end
    end
  end
end
