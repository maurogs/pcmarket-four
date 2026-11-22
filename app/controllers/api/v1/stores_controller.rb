module Api
  module V1
    class StoresController < BaseController
      def show
        @store = Store.friendly.find(params[:slug])
        @listings_count = @store.listings.visible.count
        @follow = current_user ? current_user.follows.find_by(store_id: @store.id) : nil

        cache_public_read!(@store)
        return if performed?

        render :show, formats: :json
      end
    end
  end
end
