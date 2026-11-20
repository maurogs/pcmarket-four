# Applies Stripe webhook events to the local state (Phase 4 step 4b). The
# controller verifies the signature and hands over the decoded event; this
# service owns the business rules and the idempotency: every handled event
# id lands in stripe_events, so Stripe's at-least-once redeliveries (and
# concurrent duplicates, via the unique index) never re-run a transition.
#
#   Payments::WebhookHandler.call(event) → true (handled) / false (duplicate)
#
# Unknown event types are recorded and ignored (the controller answers 200
# either way so Stripe stops retrying them). Order transitions are guarded
# by their may_*? predicates, so even a fresh duplicate cannot double-pay.
module Payments
  class WebhookHandler
    def self.call(event)
      new(event).call
    end

    def initialize(event)
      @event = event
    end

    def call
      return false if StripeEvent.exists?(stripe_id: event.id)

      handle
      StripeEvent.create!(stripe_id: event.id, event_type: event.type,
                          processed_at: Time.current, payload: payload)
      true
    rescue ActiveRecord::RecordNotUnique
      false
    end

    private

    attr_reader :event

    def handle
      case event.type
      when "checkout.session.completed" then session_completed(event.data.object)
      when "checkout.session.expired" then session_expired(event.data.object)
      when "charge.refunded" then charge_refunded(event.data.object)
      when "account.updated" then account_updated(event.data.object)
      end
    end

    # The raw event for the audit trail; Stripe objects serialize to their
    # JSON representation.
    def payload
      JSON.parse(event.to_json)
    end

    # Paid session → the whole checkout group becomes paid and keeps the
    # payment intent (refunds and disputes are matched through it).
    def session_completed(session)
      return unless session.payment_status == "paid"
      return if group_of(session).blank?

      orders_of(session).find_each do |order|
        order.update!(stripe_payment_intent_id: session.payment_intent)
        order.mark_paid! if order.may_mark_paid?
      end
    end

    # The buyer never came back from Checkout within the expiry → release
    # the reserved stock (cancel! restocks through the AASM callback).
    def session_expired(session)
      return if group_of(session).blank?

      orders_of(session).where(status: "pending").find_each do |order|
        order.cancel!("payment_expired")
      end
    end

    # Fully refunded charge → refund every order paid by that intent.
    def charge_refunded(charge)
      return unless charge.amount_captured.to_i == charge.amount_refunded.to_i
      return if charge.payment_intent.blank?

      Order.where(stripe_payment_intent_id: charge.payment_intent).find_each do |order|
        order.refund! if order.may_refund?
      end
    end

    # Stripe pushes account changes → refresh the cached Connect flags
    # (mirrors Payments::ConnectOnboarding.sync! without an API round-trip).
    def account_updated(account)
      store = Store.find_by(stripe_account_id: account.id)
      return unless store

      boolean = ActiveModel::Type::Boolean.new
      store.update!(
        stripe_charges_enabled: boolean.cast(account.charges_enabled),
        stripe_payouts_enabled: boolean.cast(account.payouts_enabled),
        stripe_details_submitted: boolean.cast(account.details_submitted),
        stripe_synced_at: Time.current
      )
    end

    def group_of(session)
      session.metadata&.checkout_group.presence
    end

    def orders_of(session)
      Order.where(checkout_group: group_of(session))
    end
  end
end
