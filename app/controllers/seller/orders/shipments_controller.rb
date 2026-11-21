module Seller
  module Orders
    class ShipmentsController < BaseController
      def create
        order = seller_order
        if order.ship!(current_user, carrier: params.dig(:order, :carrier),
                       tracking_number: params.dig(:order, :tracking_number))
          redirect_to seller_order_path(order), notice: t("seller.orders.shipment.created")
        else
          redirect_to seller_order_path(order), alert: t("seller.orders.shipment.invalid")
        end
      end

      private

      def seller_order
        current_user.orders_as_seller.find_by!(number: params[:order_id])
      end
    end
  end
end
