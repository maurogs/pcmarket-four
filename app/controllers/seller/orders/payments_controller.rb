module Seller
  module Orders
    class PaymentsController < BaseController
      def create
        order = current_user.orders_as_seller.find_by!(number: params[:order_id])
        if order.mark_paid!(current_user, reference: "cash_on_pickup")
          redirect_to seller_order_path(order), notice: t("seller.orders.payment.created")
        else
          redirect_to seller_order_path(order), alert: t("seller.orders.payment.invalid")
        end
      end
    end
  end
end
