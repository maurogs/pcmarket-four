class CartController < ApplicationController
  def show
    scope = if current_user
      CartItem.where(user_id: current_user.id)
    else
      token = cookies.signed[:cart_token]
      token.present? ? CartItem.where(cart_token: token) : CartItem.none
    end

    @items = scope.includes(listing: [ :store, { images_attachments: :blob } ])
                 .order(created_at: :desc).to_a
    @subtotal_cents = @items.sum(&:subtotal_cents)
  end
end
