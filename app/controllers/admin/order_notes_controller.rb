module Admin
  class OrderNotesController < BaseController
    def create
      order = Order.find_by!(number: params[:order_number])
      authorize_admin!(order, :note?)

      note = order.order_notes.new(author: current_user, body: params[:body].to_s.strip)
      if note.save
        audit!("order.note_added", order, changeset: { "note" => note.body })
        redirect_to admin_order_path(order), notice: t("admin.orders.note_added")
      else
        redirect_to admin_order_path(order), alert: t("admin.orders.note_required")
      end
    end
  end
end
