module Seller
  module Orders
    class CancellationsController < BaseController
      def create
        order = current_user.orders_as_seller.find_by!(number: params[:order_id])
        reason = params.dig(:order, :reason).presence || "seller_cancelled"

        if order.cancel!(current_user, reason)
          redirect_to seller_order_path(order), notice: t("seller.orders.cancellation.created")
        else
          redirect_to seller_order_path(order), alert: t("seller.orders.cancellation.invalid")
        end
      end
    end
  end
end
