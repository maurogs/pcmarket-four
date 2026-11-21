module Admin
  # Resolves a disputed order and sends the resolution message to both parties
  # through OrderNotifier (in-app notification plus email).
  class DisputeResolution
    OUTCOMES = %w[refund release].freeze

    def self.call(admin, order, outcome:, message:)
      new(admin, order, outcome: outcome, message: message).call
    end

    def initialize(admin, order, outcome:, message:)
      @admin = admin
      @order = order
      @outcome = outcome.to_s
      @message = message.to_s.strip
    end

    def call
      return false unless OUTCOMES.include?(@outcome)

      @order.resolve_dispute!(@admin, outcome: @outcome, message: @message)
    end
  end
end
