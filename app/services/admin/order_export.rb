module Admin
  # Filtered order export. CSV is generated manually because Ruby 4 removed
  # the csv library from the default gems.
  class OrderExport
    HEADERS = %w[number status fulfilment payment_method buyer_email seller total_cents currency created_at].freeze

    def initialize(params = {})
      @params = params
    end

    def to_csv
      lines = [ HEADERS.join(",") ]
      Admin::OrderQuery.new(@params).call.find_each do |order|
        lines << [
          order.number,
          order.status,
          order.fulfilment,
          order.payment_method,
          order.buyer_email,
          order.seller.email,
          order.total_cents,
          order.currency,
          order.created_at.iso8601
        ].map { |value| quote(value) }.join(",")
      end
      lines.join("\n") + "\n"
    end

    def filename
      "pcmarket-orders-#{Date.current.iso8601}.csv"
    end

    private

    def quote(value)
      text = value.to_s
      %("#{text.gsub('"', '""')}")
    end
  end
end
