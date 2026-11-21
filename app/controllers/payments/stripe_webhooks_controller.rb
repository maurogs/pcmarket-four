module Payments
  class StripeWebhooksController < ActionController::Base
    skip_forgery_protection

    def create
      Stripe.new.handle_webhook(request)
      head :ok
    rescue Payments::SignatureError
      head :bad_request
    end
  end
end
