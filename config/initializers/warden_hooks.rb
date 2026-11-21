# Merge a guest cart into the authenticated user's cart on every sign-in,
# including OmniAuth and remember-me flows.
Warden::Manager.after_authentication do |user, auth, _options|
  request = ActionDispatch::Request.new(auth.env)
  token = request.cookie_jar.signed[:cart_token]
  next if token.blank?

  CartMerger.new(user: user, token: token).call
  request.cookie_jar.delete(:cart_token)
rescue StandardError => e
  Rails.logger.warn("Cart merge failed for user #{user&.id}: #{e.message}")
end
