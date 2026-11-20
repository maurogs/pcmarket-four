module CartHelper
  # Unit count for the header badge. Guests without the cart cookie never hit
  # the DB; Current.cart is memoized by CurrentCart on cart pages, so those
  # requests reuse the already-loaded cart.
  def cart_badge_count
    return 0 unless AppSettings.enabled?(:checkout_enabled)

    if (cart = Current.cart)
      cart.count
    elsif user_signed_in?
      current_user.cart&.count || 0
    elsif (token = cookies.signed.permanent[Cart::COOKIE])
      Cart.guest.find_by(token: token)&.count || 0
    else
      0
    end
  end
end
