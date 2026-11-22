module Api
  module V1
    module Me
      class ListingsController < BaseController
        before_action :authenticate!

        def index
          status = params[:status].to_s
          status = "all" unless Listing.statuses.key?(status)
          scope = Listing.seller_board(current_user, status: status, query: params[:q])
          @listings, @pagy = paginate(scope)
          render "api/v1/me/listings/index", formats: :json
        end
      end
    end
  end
end
