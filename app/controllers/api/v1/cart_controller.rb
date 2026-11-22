module Api
  module V1
    class CartController < BaseController
      before_action :authenticate!

      def show
        @summary = current_user_cart
        render :show, formats: :json
      end

      private

      def current_user_cart
        CartSummary.for(user: current_user)
      end
    end
  end
end
