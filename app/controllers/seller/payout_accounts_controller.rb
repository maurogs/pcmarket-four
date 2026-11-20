# Seller payout account (Stripe Connect onboarding, Phase 4 step 4a):
# /:locale/seller/payout_account. Singular — one store per seller, so the
# URL never carries an id. The feature is double-gated (payments_enabled
# flag + Payments.configured?), but the page never 404s: while payouts are
# not active it explains that instead, so the sidebar link is never a dead
# end. create hands the seller Stripe's hosted onboarding (303 off-site);
# Stripe itself calls the return_url afterwards.
module Seller
  class PayoutAccountsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_store
    before_action :redirect_to_open_store

    def show
      @payouts_available = payouts_available?
      return unless @payouts_available && @store.stripe_account_id.present? && @store.stripe_sync_stale?

      @sync_result = Payments::ConnectOnboarding.sync!(@store)
    end

    def create
      unless payouts_available?
        redirect_to seller_payout_account_path, alert: t(".not_available")
        return
      end

      result = Payments::ConnectOnboarding.account_link_for(
        @store, return_url: seller_payout_account_url, refresh_url: seller_payout_account_url
      )
      if result.success?
        redirect_to result.url, status: :see_other, allow_other_host: true
      else
        redirect_to seller_payout_account_path, alert: result.errors.first
      end
    end

    private

    def set_store
      @store = current_user.store
    end

    # No store yet — the payouts page needs one, so bounce to the opening flow.
    def redirect_to_open_store
      redirect_to new_seller_store_path unless @store
    end

    def payouts_available?
      AppSettings.enabled?(:payments_enabled) && Payments.configured?
    end
  end
end
