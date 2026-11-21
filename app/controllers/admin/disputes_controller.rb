module Admin
  class DisputesController < BaseController
    before_action :set_order, only: :show

    def index
      authorize_admin!(Order, :index?)

      @query = Admin::DisputeQuery.new(filter_params)
      @disputes = @query.call
      @pagy, @disputes = pagy(@disputes, limit: pagination_limit)
    end

    def show
      authorize_admin!(Order, :show?)

      @events = @order.order_events.chronological.includes(:actor)
      @conversation = related_conversation
      @messages = @conversation&.messages&.includes(:sender) || []
      @notes = @order.order_notes.chronological.includes(:author)
      @audit_logs = AdminAuditLog.where(auditable: @order).includes(:admin).recent.limit(30)
      @dispute_event = @order.order_events.where(kind: "dispute_opened").order(:created_at).last
    end

    private

    def set_order
      @order = Order.where(status: :disputed)
                    .includes(:buyer, :seller, :store, { order_items: { listing: { images_attachments: :blob } } })
                    .find_by!(number: params[:id])
    end

    def related_conversation
      return nil if @order.buyer_id.blank?

      Conversation.where(buyer_id: @order.buyer_id, seller_id: @order.seller_id,
                         listing_id: @order.order_items.select(:listing_id))
                  .order(created_at: :desc).first
    end

    def filter_params
      params.permit(:q, :reason)
    end
  end
end
