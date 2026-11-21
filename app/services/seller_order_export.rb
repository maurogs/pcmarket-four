class SellerOrderExport
  HEADERS = %w[number date buyer status items subtotal shipping commission total net].freeze

  def initialize(user, filter: "to_ship", query: nil)
    @user = user
    @filter = filter
    @query = query
  end

  def call
    lines = [ HEADERS.join(",") ]
    orders.each do |order|
      lines << [
        order.number,
        order.created_at.iso8601,
        order.buyer_email.presence || order.buyer&.email,
        order.status,
        order.order_items.sum(&:quantity),
        order.subtotal_cents,
        order.shipping_cents,
        order.commission_cents,
        order.total_cents,
        order.net_to_seller_cents
      ].map { |value| escape(value) }.join(",")
    end
    lines.join("\n")
  end

  private

  attr_reader :user, :filter, :query

  def orders
    Order.seller_orders(user, filter: filter, query: query)
  end

  def escape(value)
    text = value.to_s
    return text unless text.include?(",") || text.include?('"') || text.include?("\n")

    %("#{text.gsub('"', '""')}")
  end
end
