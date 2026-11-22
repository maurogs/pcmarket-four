module Api
  module V1
    module Stores
      class ListingsController < BaseController
        def index
          @store = Store.friendly.find(params[:store_slug])
          @search = ListingSearch.new(params: search_params, base: @store.listings.visible)

          per_page = params[:per_page].to_i
          per_page = ListingSearch::PER_PAGE if per_page <= 0
          per_page = [ per_page, 100 ].min
          pages = [ (@search.total_count.to_f / per_page).ceil, 1 ].max
          page = [ [ params[:page].to_i, 1 ].max, pages ].min
          @pagy = Pagy.new(count: @search.total_count, page: page, limit: per_page)
          @listings = @search.relation.offset(@pagy.offset).limit(@pagy.limit).to_a

          cache_public_read!(extra: [ @store, @search.digest ])
          return if performed?

          render "api/v1/listings/index", formats: :json
        end

        private

        def search_params
          params.permit(:q, :min_price, :max_price, :sort, :condition, :free_shipping,
                        { condition: [], labels: [], tags: [], region_id: [], shipping: [], f: {} }).to_h
        end
      end
    end
  end
end
