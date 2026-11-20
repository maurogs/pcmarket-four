# POST /cart_items?listing_id=… — add to cart (the listing page's buttons;
# buy_now=1 just redirects to the cart until checkout lands in step 3).
# PATCH/DELETE /cart_items/:id — change quantity / remove. Turbo gets a
# stream refreshing the header badge and the toast area; plain HTML falls
# back to a redirect back. Guests get a cookie cart created on first add.
class CartItemsController < ApplicationController
  include CurrentCart

  before_action :require_checkout_enabled
  before_action :set_cart_item, only: %i[update destroy]

  def create
    listing = Listing.find_by_param(params[:listing_id])
    @outcome = cart_for_adding.add(listing, quantity: quantity_param)
    message = outcome_message(@outcome)

    respond_to do |format|
      format.turbo_stream do
        flash.now[@outcome.success? ? :notice : :alert] = message
        render :cart_update, formats: [ :turbo_stream ]
      end
      format.html do
        if @outcome.success? && params[:buy_now].present?
          redirect_to cart_path, notice: message
        else
          respond_with_redirect(message, alert: !@outcome.success?)
        end
      end
    end
  end

  def update
    listing = @cart_item.listing
    requested = quantity_param
    capped = [ requested, listing.quantity ].min
    @cart_item.update!(quantity: capped)

    if capped < requested
      respond_with_flash(t("cart_items.flashes.capped", count: capped), alert: true)
    else
      respond_with_flash(t("cart_items.flashes.updated"), alert: false)
    end
  end

  def destroy
    @cart_item.destroy!
    respond_with_flash(t("cart_items.flashes.removed"), alert: false)
  end

  private

  def set_cart_item
    @cart_item = current_cart&.cart_items&.find_by(id: params[:id])
    render_not_found unless @cart_item
  end

  def quantity_param
    [ params[:quantity].to_i, 1 ].max
  end

  def outcome_message(outcome)
    case outcome.status
    when :added then t("cart_items.flashes.added")
    when :increased then t("cart_items.flashes.increased")
    when :capped then t("cart_items.flashes.capped", count: outcome.item.quantity)
    when :own_listing then t("cart_items.flashes.own_listing")
    else t("cart_items.flashes.not_available")
    end
  end

  def respond_with_flash(message, alert:)
    key = alert ? :alert : :notice

    respond_to do |format|
      format.turbo_stream do
        flash.now[key] = message
        render :cart_update, formats: [ :turbo_stream ]
      end
      format.html { respond_with_redirect(message, alert: alert) }
    end
  end

  def respond_with_redirect(message, alert:)
    key = alert ? :alert : :notice
    redirect_back_or_to cart_path, status: :see_other, key => message
  end
end
