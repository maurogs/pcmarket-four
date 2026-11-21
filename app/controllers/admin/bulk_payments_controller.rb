module Admin
  class BulkPaymentsController < BaseController
    def create
      authorize_admin!(Order, :bulk_payment?)

      reference = params[:payment_reference].to_s.strip
      if reference.blank?
        redirect_to admin_payments_path, alert: t("admin.orders.reference_required")
        return
      end

      @summary = Admin::BulkPayment.call(current_user, params[:order_numbers], reference: reference)
      Order.where(number: @summary.paid).find_each do |order|
        audit!("order.paid", order,
               changeset: { "status" => [ "pending_payment", "paid" ],
                            "payment_reference" => reference })
      end
      render :create, status: :ok
    end
  end
end
