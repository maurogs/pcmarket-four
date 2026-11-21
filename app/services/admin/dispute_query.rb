module Admin
  # Disputed orders, oldest first so the longest-running case surfaces first.
  class DisputeQuery
    def initialize(params = {})
      @params = params.to_h.with_indifferent_access
    end

    def call
      scope = Order.where(status: :disputed)
                   .includes(:buyer, :seller, :store, :order_items, order_events: :actor)
      scope = filter_query(scope)
      scope = filter_reason(scope)
      scope.order(Arel.sql("orders.disputed_at ASC NULLS LAST, orders.created_at ASC"))
    end

    private

    attr_reader :params

    def filter_query(scope)
      query = params[:q].to_s.strip
      return scope if query.blank?

      pattern = "%#{Order.sanitize_sql_like(query)}%"
      scope.where("orders.number ILIKE :q OR orders.buyer_email ILIKE :q", q: pattern)
    end

    def filter_reason(scope)
      reason = params[:reason].to_s
      return scope unless Order::DISPUTE_REASONS.include?(reason)

      scope.where(id: OrderEvent.where(kind: "dispute_opened")
                                 .where("order_events.data->>'reason' = ?", reason)
                                 .select(:order_id))
    end
  end
end
