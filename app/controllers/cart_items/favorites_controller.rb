module CartItems
  class FavoritesController < ApplicationController
    before_action :authenticate_user!

    def create
      item = current_user.cart_items.find(params[:cart_item_id])
      listing = item.listing
      current_user.favorites.find_or_create_by!(listing: listing)
      item.destroy!
      @cart_summary = nil
      summary = cart_summary

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("cart-count", partial: "shared/cart_badge", locals: { count: summary.item_count }),
            turbo_stream.replace("cart-groups", partial: "cart/groups", locals: { summary: summary }),
            turbo_stream.replace("cart-summary", partial: "cart/summary", locals: { summary: summary }),
            turbo_stream.append("flash-messages", partial: "shared/flash_item",
                                locals: { message: t("cart.saved_to_favourites"), type: :notice })
          ]
        end
        format.html { redirect_to cart_path, notice: t("cart.saved_to_favourites") }
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to cart_path, alert: t("cart.errors.unavailable")
    end
  end
end
