module Seller
  module Orders
    class PickupsController < BaseController
      def create
        order = current_user.orders_as_seller.find_by!(number: params[:order_id])
        if order.mark_ready_for_pickup!(current_user)
          redirect_to seller_order_path(order), notice: t("seller.orders.pickup.created")
        else
          redirect_to seller_order_path(order), alert: t("seller.orders.pickup.invalid")
        end
      end
    end
  end
end
