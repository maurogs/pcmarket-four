module Admin
  # Marks a pasted list of bank-transfer orders as paid and returns a summary
  # the reconciliation screen can render.
  class BulkPayment
    Result = Struct.new(:paid, :not_found, :wrong_status, keyword_init: true) do
      def total
        paid.size + not_found.size + wrong_status.size
      end
    end

    def self.call(admin, raw_numbers, reference:)
      new(admin, raw_numbers, reference: reference).call
    end

    def initialize(admin, raw_numbers, reference:)
      @admin = admin
      @raw_numbers = raw_numbers.to_s
      @reference = reference.to_s.strip
    end

    def call
      summary = Result.new(paid: [], not_found: [], wrong_status: [])

      numbers.each do |number|
        order = Order.find_by(number: number)
        if order.nil?
          summary.not_found << number
        elsif !order.pending_payment?
          summary.wrong_status << number
        elsif order.payment_method != "bank_transfer"
          summary.wrong_status << number
        elsif order.mark_paid!(@admin, reference: @reference.presence || "bulk-reconciliation", provider: "bank_transfer")
          summary.paid << number
        else
          summary.wrong_status << number
        end
      end

      summary
    end

    private

    def numbers
      @raw_numbers.split(/[\n,;]+/).map(&:strip).reject(&:blank?).uniq
    end
  end
end
