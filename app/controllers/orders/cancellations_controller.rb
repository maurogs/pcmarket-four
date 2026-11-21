module Orders
  class CancellationsController < ApplicationController
    before_action :authenticate_user!

    def create
      @order = current_user.orders_as_buyer.find_by!(number: params[:order_number])
      authorize @order, :cancellation?

      if @order.cancel_unpaid!(reason: "buyer_cancelled")
        redirect_to order_path(@order), notice: t("orders.cancelled")
      else
        redirect_to order_path(@order), alert: t("orders.cannot_cancel")
      end
    end
  end
end
