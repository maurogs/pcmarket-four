module Admin
  class OrderRefundsController < BaseController
    def create
      order = Order.find_by!(number: params[:order_number])
      authorize_admin!(order, :refund?)

      reference = params[:refund_reference].to_s.strip
      if order.refund!(current_user, reference: reference)
        audit!("order.refunded", order, changeset: { "status" => [ "previous", "refunded" ],
                                                    "refund_reference" => reference })
        redirect_to admin_order_path(order), notice: t("admin.orders.refunded")
      else
        redirect_to admin_order_path(order), alert: t("admin.orders.cannot_refund")
      end
    end
  end
end
