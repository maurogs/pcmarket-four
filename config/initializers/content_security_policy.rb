# Be sure to restart your server when you modify this file.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src :self, "https://fonts.gstatic.com", :data
    policy.img_src :self, :data, :blob
    policy.object_src :none
    policy.script_src :self
    policy.style_src :self, "https://fonts.googleapis.com", :unsafe_inline
    policy.connect_src :self
    policy.media_src :self
    policy.manifest_src :self
    policy.base_uri :self
    policy.form_action :self
    policy.frame_ancestors :none
    policy.upgrade_insecure_requests if Rails.env.production?
  end

  config.content_security_policy_nonce_generator = lambda do |request|
    request.session.id.presence || SecureRandom.base64(16)
  end
  config.content_security_policy_nonce_directives = %w[script-src]
  config.content_security_policy_nonce_auto = true
end
