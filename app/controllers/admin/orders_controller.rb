module Admin
  class OrdersController < BaseController
    before_action :set_order, only: :show

    def index
      authorize_admin!(Order, :index?)

      @query = Admin::OrderQuery.new(filter_params)
      @orders = @query.call
      @totals = @query.totals(@orders)
      @pagy, @orders = pagy(@orders, limit: pagination_limit)
    end

    def show
      authorize_admin!(@order, :show?)

      @events = @order.order_events.chronological.includes(:actor)
      @conversation = related_conversation
      @notes = @order.order_notes.chronological.includes(:author)
      @audit_logs = AdminAuditLog.where(auditable: @order).includes(:admin).recent.limit(30)
    end

    private

    def set_order
      @order = Order.includes(
        :buyer, :seller, :store, :review,
        { order_items: { listing: { images_attachments: :blob } } }
      ).find_by!(number: params[:number] || params[:id])
    end

    def related_conversation
      return nil if @order.buyer_id.blank?

      listing_ids = @order.order_items.select(:listing_id)
      Conversation.where(buyer_id: @order.buyer_id, seller_id: @order.seller_id, listing_id: listing_ids)
                  .order(created_at: :desc).first
    end

    def filter_params
      params.permit(:status, :fulfilment, :payment_method, :seller, :buyer_email,
                    :created_from, :created_to, :min_total, :max_total,
                    :late_shipment, :refund_needed, :sort, :direction)
    end
  end
end
