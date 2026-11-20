# GET /sell — "Sell on PCMarket" landing page (Phase 3 step 6). Static
# marketing copy plus two data-driven sections served by SellingPage.
# Anonymous responses get a public 1-hour HTTP cache; the body is also
# fragment-cached per locale + fee/payment flags + data stamp (see the view).
class SellingsController < ApplicationController
  def show
    expires_in 1.hour, public: true unless user_signed_in?

    @selling = SellingPage.new
    @commission_enabled = AppSettings.enabled?(:commission_enabled)
    @commission_percent = AppSettings.get(:commission_percent, 0).to_f
    @payments_enabled = AppSettings.enabled?(:payments_enabled)
  end
end
