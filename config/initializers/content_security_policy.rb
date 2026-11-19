# Be sure to restart your server when you modify this file.

# Application-wide Content Security Policy. Everything is self-hosted
# (fonts included), so the policy stays strict: 'self' plus per-request
# nonces for the importmap and the theme bootstrap script.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self
    policy.img_src     :self, :data, :blob
    policy.object_src  :none
    policy.script_src  :self
    policy.style_src   :self
    policy.form_action :self
    # Specify URI for violation reports
    # policy.report_uri "/csp-violation-report-endpoint"
  end

  # Generate session nonces for permitted importmap, inline scripts, and inline styles.
  # A fresh random nonce per response (session.id would be nil for anonymous
  # requests that never touch the session).
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]

  # Automatically add `nonce` to `javascript_tag`, `javascript_include_tag`, and `stylesheet_link_tag`
  # if the corresponding directives are specified in `content_security_policy_nonce_directives`.
  config.content_security_policy_nonce_auto = true
end
