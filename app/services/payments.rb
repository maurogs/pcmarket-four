# Configuration facade over the Stripe gem (see config/initializers/stripe.rb).
# The whole payments feature is double-gated: the `payments_enabled` AppSettings
# flag (per-market switch, admin-controlled) AND Payments.configured? (are the
# credentials present at all). Callers must check both before touching Stripe.
#
# Env vars (falling back to `credentials.stripe.*`): STRIPE_SECRET_KEY,
# STRIPE_PUBLISHABLE_KEY, STRIPE_WEBHOOK_SECRET — documented in the README.
module Payments
  module_function

  def secret_key
    ENV["STRIPE_SECRET_KEY"] || Rails.application.credentials.dig(:stripe, :secret_key)
  end

  def publishable_key
    ENV["STRIPE_PUBLISHABLE_KEY"] || Rails.application.credentials.dig(:stripe, :publishable_key)
  end

  def webhook_secret
    ENV["STRIPE_WEBHOOK_SECRET"] || Rails.application.credentials.dig(:stripe, :webhook_secret)
  end

  # Connect onboarding needs the secret key; the webhook receiver (Phase 4b)
  # needs the signing secret — both must be present to call the feature live.
  def configured?
    secret_key.present? && webhook_secret.present?
  end

  # The single gate callers should check: the per-market switch AND usable
  # credentials. (AppSettings lives here so views/forms never combine them.)
  def active?
    AppSettings.enabled?(:payments_enabled) && configured?
  end
end
