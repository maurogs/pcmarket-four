# GET /cart — the cart page (Phase 4 step 1). Guests see the cart behind
# their cookie (empty state when they have none); signed-in users get their
# cart, created lazily. Cart#refresh! drops sold/invisible items and syncs
# price changes before rendering, with translated notices on top.
# Checkout itself ships in Phase 4 step 3 — the CTA links to checkout_path.
class CartsController < ApplicationController
  include CurrentCart

  before_action :require_checkout_enabled

  def show
    @cart = current_cart
    @notices = @cart ? @cart.refresh! : []
    @groups = @cart ? @cart.items_by_store : []
  end
end
