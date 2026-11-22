module Api
  module V1
    module Stores
      class ReviewsController < BaseController
        def index
          @store = Store.friendly.find(params[:store_slug])
          scope = @store.reviews.where(published: true).includes(:reviewer).order(created_at: :desc)
          @reviews, @pagy = paginate(scope)

          cache_public_read!(extra: [ @store, @pagy.count ])
          return if performed?

          render :index, formats: :json
        end
      end
    end
  end
end
