class CartItemsController < ApplicationController
  MAX_QUANTITY = 10

  def create
    listing = Listing.visible.find(params[:listing_id])

    if current_user && listing.user_id == current_user.id
      return respond_error(t("cart.errors.own_listing"), listing)
    end

    if listing.store&.on_vacation?
      return respond_error(t("cart.errors.vacation"), listing)
    end

    item = cart_scope.find_or_initialize_by(listing_id: listing.id)
    item.user = current_user if current_user
    item.cart_token = guest_token unless current_user
    item.quantity = capped_quantity(item.quantity.to_i + requested_quantity, listing)
    item.save!

    respond_success(listing, item)
  rescue ActiveRecord::RecordNotFound
    respond_error(t("cart.errors.unavailable"))
  end

  def update
    item = cart_scope.find(params[:id])
    quantity = requested_quantity.to_i

    if quantity.zero?
      item.destroy!
    else
      item.update!(quantity: capped_quantity(quantity, item.listing))
    end

    @cart_summary = nil

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("cart-count", partial: "shared/cart_badge", locals: { count: cart_summary.item_count }),
          turbo_stream.replace("cart-groups", partial: "cart/groups", locals: { summary: cart_summary }),
          turbo_stream.replace("cart-summary", partial: "cart/summary", locals: { summary: cart_summary })
        ]
      end
      format.html { redirect_to cart_path }
    end
  end

  def destroy
    item = cart_scope.find(params[:id])
    item.destroy!

    respond_to do |format|
      format.turbo_stream { render_cart_updates }
      format.html { redirect_to cart_path, notice: t("cart.removed") }
    end
  end

  private

  def render_cart_updates
    @cart_summary = nil
    summary = cart_summary

    render turbo_stream: [
      turbo_stream.replace("cart-count", partial: "shared/cart_badge", locals: { count: summary.item_count }),
      turbo_stream.replace("cart-groups", partial: "cart/groups", locals: { summary: summary }),
      turbo_stream.replace("cart-summary", partial: "cart/summary", locals: { summary: summary })
    ]
  end

  def cart_scope
    current_user ? CartItem.where(user_id: current_user.id) : CartItem.where(cart_token: guest_token)
  end

  def guest_token
    cookies.signed.permanent[:cart_token] ||= SecureRandom.uuid
  end

  def requested_quantity
    value = params[:quantity].to_i
    value = 1 if value < 1
    [ value, MAX_QUANTITY ].min
  end

  def capped_quantity(quantity, listing)
    [ [ quantity, listing.quantity.to_i ].min, 1 ].max
  end

  def respond_success(listing, item)
    if params[:buy_now].present?
      redirect_to cart_path, notice: t("cart.added", title: listing.title)
      return
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("cart-count", partial: "shared/cart_badge"),
          turbo_stream.append("flash-messages", partial: "shared/flash_item",
                              locals: { message: t("cart.added", title: listing.title), type: :notice })
        ]
      end
      format.html do
        redirect_back fallback_location: listing_path(listing),
                    notice: t("cart.added", title: listing.title)
      end
    end
  end

  def respond_error(message, listing = nil)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.append(
          "flash-messages", partial: "shared/flash_item",
          locals: { message: message, type: :alert }
        )
      end
      format.html do
        redirect_back fallback_location: listing ? listing_path(listing) : cart_path,
                    alert: message
      end
    end
  end
end
