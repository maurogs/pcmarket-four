module Payments
  # Computes the payment methods offered for a given cart. Cash on pickup is
  # only possible when every seller group is pickup-only; Stripe requires both
  # the setting and the API key.
  class Availability
    METHODS = %w[bank_transfer cash_on_pickup stripe].freeze
    LABEL_KEYS = {
      "bank_transfer" => "checkout.payment.methods.bank_transfer",
      "cash_on_pickup" => "checkout.payment.methods.cash_on_pickup",
      "stripe" => "checkout.payment.methods.stripe"
    }.freeze

    def initialize(summary)
      @summary = summary
    end

    def options
      METHODS.select { |method| available?(method) }
    end

    def available?(method)
      case method.to_s
      when "bank_transfer" then bank_transfer?
      when "cash_on_pickup" then cash_on_pickup?
      when "stripe" then stripe?
      else false
      end
    end

    def bank_transfer?
      Setting.enabled?("payment_bank_transfer_enabled")
    end

    def cash_on_pickup?
      @summary.present? && @summary.all_pickup?
    end

    def stripe?
      Setting.enabled?("stripe_enabled") && ENV["STRIPE_SECRET_KEY"].present?
    end
  end

  def self.provider_for(method)
    case method.to_s
    when "stripe" then Stripe.new
    when "cash_on_pickup" then CashOnPickup.new
    else BankTransfer.new
    end
  end
end
