# One row per Stripe webhook event id (see Payments::WebhookHandler): the
# unique stripe_id index makes webhook handling idempotent across Stripe's
# at-least-once deliveries. payload keeps the raw event for debugging.
class StripeEvent < ApplicationRecord
  validates :stripe_id, presence: true, uniqueness: true
  validates :event_type, presence: true
end
