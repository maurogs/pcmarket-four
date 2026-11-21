module Admin
  # Filtered, sorted order relation used by the admin order table, the CSV
  # export and the reconciliation screen. Sort keys are whitelisted.
  class OrderQuery
    SORTS = {
      "created_at" => "orders.created_at",
      "number" => "orders.number",
      "total_cents" => "orders.total_cents",
      "status" => "orders.status",
      "paid_at" => "orders.paid_at",
      "seller" => "orders.seller_id"
    }.freeze
    DEFAULT_SORT = "created_at".freeze
    DIRECTIONS = %w[asc desc].freeze

    def initialize(params = {})
      @params = params.to_h.with_indifferent_access
    end

    def call
      scope = base_scope
      scope = filter_status(scope)
      scope = filter_fulfilment(scope)
      scope = filter_payment_method(scope)
      scope = filter_seller(scope)
      scope = filter_buyer_email(scope)
      scope = filter_created(scope)
      scope = filter_total(scope)
      scope = filter_late_shipment(scope)
      scope = filter_refund_needed(scope)
      order(scope)
    end

    def sort
      key = @params[:sort].to_s
      SORTS.key?(key) ? key : DEFAULT_SORT
    end

    def direction
      DIRECTIONS.include?(@params[:direction].to_s) ? @params[:direction].to_s : "desc"
    end

    def totals(scope)
      {
        count: scope.count,
        gmv_cents: scope.sum(:total_cents),
        commission_cents: scope.sum(:commission_cents)
      }
    end

    def payment_deadline
      Setting.get("payment_deadline_days", 3).to_i.days
    end

    private

    attr_reader :params

    def base_scope
      Order.includes(:buyer, :seller, :store, order_items: { listing: { images_attachments: :blob } })
    end

    def filter_status(scope)
      status = params[:status].to_s
      Order.statuses.key?(status) ? scope.where(status: status) : scope
    end

    def filter_fulfilment(scope)
      fulfilment = params[:fulfilment].to_s
      Order.fulfilments.key?(fulfilment) ? scope.where(fulfilment: fulfilment) : scope
    end

    def filter_payment_method(scope)
      method = params[:payment_method].to_s
      return scope unless %w[bank_transfer cash_on_pickup stripe].include?(method)

      scope.where(payment_method: method)
    end

    def filter_seller(scope)
      query = params[:seller].to_s.strip
      return scope if query.blank?

      pattern = "%#{Order.sanitize_sql_like(query)}%"
      scope.left_joins(:seller, :store).where(
        "users.username ILIKE :q OR users.email ILIKE :q OR users.first_name ILIKE :q " \
        "OR users.last_name ILIKE :q OR stores.name ILIKE :q OR CAST(orders.seller_id AS TEXT) = :id",
        q: pattern, id: query
      )
    end

    def filter_buyer_email(scope)
      email = params[:buyer_email].to_s.strip
      return scope if email.blank?

      scope.where("orders.buyer_email ILIKE ?", "%#{Order.sanitize_sql_like(email)}%")
    end

    def filter_created(scope)
      scope = scope.where("orders.created_at >= ?", parse_date(params[:created_from]).beginning_of_day) if params[:created_from].present?
      scope = scope.where("orders.created_at <= ?", parse_date(params[:created_to]).end_of_day) if params[:created_to].present?
      scope
    end

    def filter_total(scope)
      scope = scope.where("orders.total_cents >= ?", euros_to_cents(params[:min_total])) if params[:min_total].present?
      scope = scope.where("orders.total_cents <= ?", euros_to_cents(params[:max_total])) if params[:max_total].present?
      scope
    end

    def filter_late_shipment(scope)
      return scope unless params[:late_shipment].to_s == "yes"

      scope.where(status: :paid, shipped_at: nil)
           .where("orders.paid_at <= ?", Setting.get("seller_ship_deadline_days", 3).to_i.days.ago)
    end

    def filter_refund_needed(scope)
      return scope unless params[:refund_needed].to_s == "yes"

      scope.where(refund_required: true)
    end

    def order(scope)
      scope.order(Arel.sql("#{SORTS.fetch(sort)} #{direction.upcase}")).order(id: :desc)
    end

    def parse_date(value)
      Date.parse(value.to_s)
    rescue Date::Error, ArgumentError
      Date.current
    end

    def euros_to_cents(value)
      (BigDecimal(value.to_s.tr(",", ".")) * 100).round
    rescue ArgumentError
      0
    end
  end
end
