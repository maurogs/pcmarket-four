# Cart resolution shared by the cart controllers (Phase 4 step 1):
# signed-in users get their cart (created lazily); guests get the cart behind
# the signed permanent cookie token — but only when one exists, so plain
# browsing never creates cart rows. Guest carts are merged into the user's
# cart on sign-in (config/initializers/warden_cart_merge.rb).
module CurrentCart
  extend ActiveSupport::Concern

  private

  # The visitor's cart, or nil for guests without a cart cookie. Memoized per
  # request and mirrored onto Current.cart so the header badge partial can
  # reuse it without a second query.
  def current_cart
    return @current_cart if defined?(@current_cart)

    @current_cart = resolve_current_cart
    Current.cart = @current_cart
  end

  # Like #current_cart, but creates a guest cart (and its cookie) on first
  # use — call this only from add-to-cart actions.
  def cart_for_adding
    return current_cart if current_cart

    @current_cart = Current.cart = Cart.create!
    set_cart_cookie(@current_cart)
    @current_cart
  end

  # The whole cart feature hides behind the checkout_enabled flag: routes
  # 404 and the views hide their entry points.
  def require_checkout_enabled
    render_not_found unless AppSettings.enabled?(:checkout_enabled)
  end

  def resolve_current_cart
    if user_signed_in?
      current_user.cart || current_user.create_cart!
    elsif (token = cart_cookie_token)
      Cart.guest.find_by(token: token)
    end
  end

  def cart_cookie_token
    cookies.signed.permanent[Cart::COOKIE]
  end

  def set_cart_cookie(cart)
    # httponly must be explicit — Rails 8.1 does not default it (see LocaleConcern).
    cookies.signed.permanent[Cart::COOKIE] = { value: cart.token, httponly: true }
  end
end
