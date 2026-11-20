# Merge the guest cart into the user's cart on sign-in (Phase 4 step 1).
# Warden's after_set_user hook fires for every authentication path — the
# password form, the remember-me cookie and Google OAuth — unlike Devise's
# after_sign_in_path_for, which only covers SessionsController. The scope
# and event filters keep session restores (:fetch) from re-running it.
Warden::Manager.after_set_user scope: :user, only: %i[authentication set_user] do |user, auth, _opts|
  # The env's ActionDispatch cookie jar is the one the Cookies middleware
  # commits to the response, so reads and the delete below behave exactly as
  # `cookies` does in a controller.
  cookies = ActionDispatch::Request.new(auth.env).cookie_jar
  token = cookies.signed.permanent[Cart::COOKIE]
  next if token.blank?

  guest_cart = Cart.guest.find_by(token: token)
  if guest_cart
    user_cart = user.cart || Cart.create!(user: user)
    user_cart.merge!(guest_cart)
  end
  cookies.delete(Cart::COOKIE)
end
