module Admin
  class OrderEmailsController < BaseController
    def create
      order = Order.find_by!(number: params[:order_number])
      authorize_admin!(order, :resend_email?)

      case params[:recipient].to_s
      when "seller"
        OrderMailer.placed_seller(order).deliver_later
        audit!("order.email_resent", order, changeset: { "recipient" => "seller" })
        redirect_to admin_order_path(order), notice: t("admin.orders.email_sent")
      when "buyer"
        OrderMailer.placed_buyer(order).deliver_later
        audit!("order.email_resent", order, changeset: { "recipient" => "buyer" })
        redirect_to admin_order_path(order), notice: t("admin.orders.email_sent")
      else
        redirect_to admin_order_path(order), alert: t("admin.orders.invalid_recipient")
      end
    end
  end
end
