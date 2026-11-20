# POST /webhooks/stripe — Stripe's server-to-server event feed (Phase 4
# step 4b). Routed outside the locale scope (Stripe posts to one fixed URL)
# and exempt from CSRF and sign-in: the signature IS the authentication, so
# the raw request body is verified against Payments.webhook_secret before
# anything is touched. An invalid signature or malformed body is a 400;
# everything else is delegated to Payments::WebhookHandler and answered 200
# fast, so Stripe never retries work we already did (or never do).
class StripeWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    event = verified_event
    return head :bad_request if event.nil?

    Payments::WebhookHandler.call(event)
    head :ok
  end

  private

  def verified_event
    Stripe::Webhook.construct_event(
      request.raw_post, request.headers["Stripe-Signature"].to_s, Payments.webhook_secret
    )
  rescue Stripe::SignatureVerificationError, Stripe::InvalidRequestError, JSON::ParserError => e
    Rails.logger.warn("Stripe webhook rejected: #{e.message}")
    nil
  end
end
