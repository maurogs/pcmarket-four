module Admin
  class PaymentsController < BaseController
    def index
      authorize_admin!(Order, :index?)

      @orders = Order.pending_payment
                    .where(payment_method: "bank_transfer")
                    .includes(:buyer, :seller, :store)
                    .order(created_at: :asc)
      @deadline_days = Setting.get("payment_deadline_days", 3).to_i
      @pagy, @orders = pagy(@orders, limit: pagination_limit)
    end
  end
end
