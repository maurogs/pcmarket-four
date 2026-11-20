# Creates the Stripe Checkout Session that pays a whole checkout_group
# (Phase 4 step 4b): one line item per order item plus one shipping line per
# order, a transfer_group so the platform can split the payment out to each
# seller's connected account, and the group stamped in the metadata so the
# webhook can find the orders again.
#
#   Payments::CheckoutSessionCreator.call(orders, success_url:, cancel_url:)
#     → Result(session, errors)
#
# The idempotency key is derived from the checkout_group, so a retried POST
# never creates a second session. On success the session id is stamped on
# every order of the group (the webhook matches on it as a fallback).
# A Stripe::StripeError becomes a failed Result — callers never rescue.
module Payments
  class CheckoutSessionCreator
    Result = Struct.new(:session, :errors, keyword_init: true) do
      def success?
        errors.empty?
      end
    end

    CURRENCY = "eur".freeze
    SESSION_TTL = 30.minutes

    # I18n locale → Stripe Checkout locale ("pt" alone is not a Stripe
    # locale; the Spanish market gets European Portuguese). Unknown locales
    # fall back to Stripe's own browser detection.
    LOCALES = { "en" => "en", "es" => "es", "fr" => "fr",
                "de" => "de", "it" => "it", "pt" => "pt-PT" }.freeze

    def self.call(orders, success_url:, cancel_url:)
      new(orders, success_url: success_url, cancel_url: cancel_url).call
    end

    def initialize(orders, success_url:, cancel_url:)
      @orders = orders.to_a
      @success_url = success_url
      @cancel_url = cancel_url
    end

    def call
      return Result.new(errors: [ I18n.t("payments.checkout.no_orders") ]) if orders.empty?

      session = Stripe::Checkout::Session.create(
        session_params, { idempotency_key: "checkout-#{checkout_group}" }
      )
      Order.where(id: orders.map(&:id)).update_all(stripe_checkout_session_id: session.id)
      Result.new(session: session, errors: [])
    rescue Stripe::StripeError => e
      Rails.logger.error("Stripe Checkout failed for group #{checkout_group}: #{e.message}")
      Result.new(errors: [ I18n.t("payments.checkout.stripe_error") ])
    end

    private

    attr_reader :orders, :success_url, :cancel_url

    def checkout_group
      orders.first&.checkout_group
    end

    def session_params
      {
        mode: "payment",
        line_items: line_items,
        customer_email: orders.first.buyer_email,
        locale: LOCALES.fetch(I18n.locale.to_s, "auto"),
        success_url: success_url,
        cancel_url: cancel_url,
        expires_at: (Time.current + SESSION_TTL).to_i,
        payment_intent_data: {
          transfer_group: checkout_group,
          metadata: { checkout_group: checkout_group }
        },
        metadata: { checkout_group: checkout_group }
      }
    end

    # One line per order item, plus a single shipping line per order when
    # that order carries a shipping fee.
    def line_items
      orders.flat_map do |order|
        lines = order.order_items.map do |item|
          {
            quantity: item.quantity,
            price_data: {
              currency: CURRENCY,
              unit_amount: item.unit_price_cents,
              product_data: { name: item.title }
            }
          }
        end
        if order.shipping_cents.positive?
          lines << {
            quantity: 1,
            price_data: {
              currency: CURRENCY,
              unit_amount: order.shipping_cents,
              product_data: {
                name: I18n.t("payments.checkout.shipping_line", store: order.store.name)
              }
            }
          }
        end
        lines
      end
    end
  end
end
