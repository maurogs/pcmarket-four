# Stripe configuration (Phase 4 step 4a — seller Connect onboarding).
#
# The secret key comes from the environment in production (STRIPE_SECRET_KEY)
# and from encrypted credentials locally. The API version is PINNED so a gem
# upgrade can never silently change API behaviour — bump it deliberately,
# together with the test suite. Whether the credentials are usable at all is
# answered by Payments.configured? (app/services/payments.rb); nothing here
# calls the API, so booting without keys is safe.
Stripe.api_key = ENV["STRIPE_SECRET_KEY"] || Rails.application.credentials.dig(:stripe, :secret_key)
Stripe.api_version = "2026-11-18.endive"
