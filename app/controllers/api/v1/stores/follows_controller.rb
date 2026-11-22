module Api
  module V1
    module Stores
      class FollowsController < BaseController
        before_action :authenticate!
        before_action :set_store

        def create
          follow = current_user.follows.find_or_create_by!(store: @store)
          @store.reload

          render "api/v1/stores/follows/show", formats: :json, status: :created,
                 locals: { follow: follow }
        end

        def destroy
          current_user.follows.where(store_id: @store.id).destroy_all
          @store.reload

          render "api/v1/stores/follows/show", formats: :json, locals: { follow: nil }
        end

        private

        def set_store
          @store = Store.friendly.find(params[:store_slug])
        end
      end
    end
  end
end
