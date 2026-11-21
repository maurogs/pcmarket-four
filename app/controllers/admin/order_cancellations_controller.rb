module Admin
  class OrderCancellationsController < BaseController
    def create
      order = Order.find_by!(number: params[:order_number])
      authorize_admin!(order, :cancel?)

      reason = params[:reason].to_s.strip
      if order.cancel!(current_user, reason.presence || "admin_cancelled")
        audit!("order.cancelled", order, changeset: { "status" => [ "previous", "cancelled" ],
                                                     "reason" => reason })
        redirect_to admin_order_path(order), notice: t("admin.orders.cancelled")
      else
        redirect_to admin_order_path(order), alert: t("admin.orders.cannot_cancel")
      end
    end
  end
end
