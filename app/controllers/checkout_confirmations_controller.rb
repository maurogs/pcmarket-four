# GET /checkout_confirmations/:group — the post-checkout receipt for one
# checkout_group (Phase 4 step 3): the orders placed per store, their
# totals and the payment next steps. Signed-in buyers only see their own
# orders; guests only the groups placed in this session (see
# CheckoutsController#remember_checkout_group) — anything else is a 404.
# While a Stripe payment is still in flight (Phase 4 step 4b) the page
# shows a "processing" card and self-refreshes every few seconds — through
# a meta refresh with a bumping ?tries= counter, capped at ~1 minute so a
# never-completing payment cannot make the browser poll forever (the
# checkout.session.expired webhook cancels the orders meanwhile).
class CheckoutConfirmationsController < ApplicationController
  include CurrentCart

  REFRESH_SECONDS = 5
  MAX_REFRESHES = 12 # 12 × 5s ≈ one minute of polling

  before_action :require_checkout_enabled

  def show
    @orders = visible_orders
    render_not_found if @orders.empty?
    return if performed?

    @processing = @orders.any?(&:pending?) && @orders.first.payment_method == "stripe"
    @refresh_seconds = REFRESH_SECONDS
    @refresh_url = payment_refresh_url if @processing
  end

  private

  def visible_orders
    scope = Order.where(checkout_group: params[:group]).includes(:store, order_items: :listing)

    if user_signed_in?
      scope.where(buyer_id: current_user.id)
    elsif session[:checkout_groups].to_a.include?(params[:group])
      scope
    else
      Order.none
    end
  end

  # nil once the refresh budget is spent — the view then stops reloading.
  def payment_refresh_url
    tries = params[:tries].to_i
    return nil if tries >= MAX_REFRESHES

    checkout_confirmation_url(@orders.first.checkout_group, tries: tries + 1)
  end
end
