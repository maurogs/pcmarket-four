module Payments
  class Stripe < Provider
    def start(orders, return_urls)
      return nil if orders.blank?

      ::Stripe.api_key = ENV["STRIPE_SECRET_KEY"]
      session = ::Stripe::Checkout::Session.create(
        mode: "payment",
        line_items: orders.map { |order| line_item(order) },
        metadata: { order_ids: orders.map(&:id).join(",") },
        client_reference_id: orders.first.checkout_token.to_s,
        success_url: return_urls[:success],
        cancel_url: return_urls[:cancel]
      )
      session.url
    end

    def handle_webhook(request)
      event = ::Stripe::Webhook.construct_event(
        request.body.read,
        request.env["HTTP_STRIPE_SIGNATURE"],
        ENV["STRIPE_WEBHOOK_SECRET"]
      )

      case event.type
      when "checkout.session.completed"
        session = event.data.object
        orders_for(session).each do |order|
          order.mark_paid!(
            reference: session.payment_intent.presence || session.id,
            provider: "stripe"
          )
        end
      when "checkout.session.expired", "checkout.session.async_payment_failed"
        session = event.data.object
        orders_for(session).each { |order| order.cancel_unpaid!(reason: "payment_expired") }
      end

      true
    rescue ::Stripe::SignatureVerificationError
      raise SignatureError
    end

    private

    def line_item(order)
      {
        quantity: 1,
        price_data: {
          currency: order.currency.to_s.downcase,
          unit_amount: order.total_cents,
          product_data: {
            name: I18n.t("checkout.stripe.line_item", number: order.number, locale: order.locale)
          }
        }
      }
    end

    def orders_for(session)
      ids = session.metadata&.[]("order_ids").to_s.split(",").map(&:to_i).reject(&:zero?)
      Order.where(id: ids)
    end
  end
end
