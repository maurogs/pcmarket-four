# GET /checkout_confirmations/:group — the post-checkout receipt for one
# checkout_group (Phase 4 step 3): the orders placed per store, their
# totals and the manual-payment next steps. Signed-in buyers only see their
# own orders; guests only the groups placed in this session (see
# CheckoutsController#remember_checkout_group) — anything else is a 404.
class CheckoutConfirmationsController < ApplicationController
  include CurrentCart

  before_action :require_checkout_enabled

  def show
    @orders = visible_orders
    render_not_found if @orders.empty?
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
end
