module Seller
  module Orders
    class PackingSlipsController < BaseController
      layout "packing_slip"

      def show
        @order = current_user.orders_as_seller
                          .includes(:buyer, :store, order_items: :listing)
                          .find_by!(number: params[:order_id])
      end
    end
  end
end
