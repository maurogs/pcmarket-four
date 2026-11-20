# Stripe Connect onboarding for seller stores (Phase 4 step 4a). Lazily
# creates the seller's Express account on first use, hands them the hosted
# onboarding link, and copies the account flags back onto the store.
#
#   Payments::ConnectOnboarding.account_link_for(store, return_url:, refresh_url:)
#     → Result(url, errors)
#   Payments::ConnectOnboarding.sync!(store)
#     → Result(url, errors)
#
# Every Stripe call is wrapped: a Stripe::StripeError becomes a failed Result
# carrying one translated message, so callers never rescue Stripe themselves.
# Only ever call this when AppSettings payments_enabled is on AND
# Payments.configured? is true (see app/services/payments.rb).
module Payments
  class ConnectOnboarding
    Result = Struct.new(:url, :errors, keyword_init: true) do
      def success?
        errors.empty?
      end
    end

    # Express accounts keep Stripe in charge of KYC; "ES" matches the only
    # launched market. business_type mirrors the store kind (Stripe wants
    # "company" for what the app calls a business account).
    def self.account_link_for(store, return_url:, refresh_url:)
      account_id = store.stripe_account_id.presence || create_account(store)

      link = Stripe::AccountLink.create({
        account: account_id,
        type: "account_onboarding",
        refresh_url: refresh_url,
        return_url: return_url
      })
      Result.new(url: link.url, errors: [])
    rescue Stripe::StripeError => e
      failure(e, store)
    end

    # Refreshes the cached account flags. The bang is aspirational: a Stripe
    # outage still returns a failed Result (the page shows an alert instead
    # of a 500), it never raises.
    def self.sync!(store)
      account = Stripe::Account.retrieve(store.stripe_account_id)
      store.update!(
        stripe_charges_enabled: ActiveModel::Type::Boolean.new.cast(account.charges_enabled),
        stripe_payouts_enabled: ActiveModel::Type::Boolean.new.cast(account.payouts_enabled),
        stripe_details_submitted: ActiveModel::Type::Boolean.new.cast(account.details_submitted),
        stripe_synced_at: Time.current
      )
      Result.new(errors: [])
    rescue Stripe::StripeError => e
      failure(e, store)
    end

    def self.create_account(store)
      account = Stripe::Account.create({
        type: "express",
        country: "ES",
        email: store.user.email,
        business_type: store.business? ? "company" : "individual",
        capabilities: {
          transfers: { requested: true },
          card_payments: { requested: true }
        },
        metadata: { store_id: store.id.to_s }
      })
      store.update!(stripe_account_id: account.id)
      account.id
    end

    def self.failure(error, store)
      Rails.logger.error("Stripe Connect failed for store #{store.id}: #{error.message}")
      Result.new(errors: [ I18n.t("payments.connect.stripe_error") ])
    end
    private_class_method :create_account, :failure
  end
end
