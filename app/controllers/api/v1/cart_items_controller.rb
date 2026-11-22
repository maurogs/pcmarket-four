module Api
  module V1
    class CartItemsController < BaseController
      before_action :authenticate!

      def create
        listing = Listing.visible.find(listing_id)
        Cart::Mutations.add(
          scope: current_user.cart_items,
          listing: listing,
          quantity: params[:quantity],
          user: current_user
        )

        respond_with_cart(:created)
      rescue Cart::Mutations::Error => error
        render_cart_error(error)
      end

      def update
        item = current_user.cart_items.find(params[:id])
        quantity = params[:quantity].to_i

        if quantity <= 0
          item.destroy!
        else
          Cart::Mutations.update(item: item, quantity: quantity)
        end

        respond_with_cart(:ok)
      rescue Cart::Mutations::Error => error
        render_cart_error(error)
      end

      def destroy
        current_user.cart_items.find(params[:id]).destroy!
        respond_with_cart(:ok)
      end

      private

      def listing_id
        value = params[:listing_id] || params[:listing_slug]
        return value if value.to_s.match?(/\A\d+\z/)

        Listing.friendly.find(value).id
      end

      def respond_with_cart(status)
        @summary = CartSummary.for(user: current_user)
        render "api/v1/cart/show", formats: :json, status: status
      end

      def render_cart_error(error)
        key = error.message_key
        message_key = key == "own_listing" ? "cart_own_listing" : "cart_#{key}"
        message_key = "cart_unavailable" unless I18n.exists?("api.errors.#{message_key}")
        render_error(key == "own_listing" ? "own_listing" : "cart_unavailable",
                     t("api.errors.#{message_key}"), status: :unprocessable_entity)
      end
    end
  end
end
