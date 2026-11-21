module Orders
  class DeliveryConfirmationsController < ApplicationController
    before_action :authenticate_user!

    def create
      order = current_user.orders_as_buyer.find_by!(number: params[:order_number])
      authorize order, :delivery_confirmation?

      if order.confirm_delivery!(current_user)
        redirect_to order_path(order), notice: t("orders.delivery.confirmed")
      else
        redirect_to order_path(order), alert: t("orders.delivery.cannot_confirm")
      end
    end
  end
end
