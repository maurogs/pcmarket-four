module Admin
  class OrderPaymentsController < BaseController
    def create
      order = Order.find_by!(number: params[:order_number])
      authorize_admin!(order, :mark_paid?)

      reference = params[:payment_reference].to_s.strip
      if reference.blank?
        redirect_to admin_order_path(order), alert: t("admin.orders.reference_required")
        return
      end

      if order.mark_paid!(current_user, reference: reference, provider: "bank_transfer")
        audit!("order.paid", order, changeset: { "status" => [ "pending_payment", "paid" ],
                                                "payment_reference" => reference })
        redirect_to admin_order_path(order), notice: t("admin.orders.paid")
      else
        redirect_to admin_order_path(order), alert: t("admin.orders.cannot_pay")
      end
    end
  end
end
