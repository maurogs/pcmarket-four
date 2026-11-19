# omniauth-rails_csrf_protection requires the request phase to be a POST
# (button_to). Tests may drive the callback directly, so keep GET there.
if defined?(OmniAuth)
  OmniAuth.config.allowed_request_methods = Rails.env.test? ? [ :get, :post ] : [ :post ]
  OmniAuth.config.logger = Rails.logger
end
