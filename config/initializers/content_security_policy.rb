# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

require "securerandom"

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.base_uri :self
    policy.form_action :self
    policy.frame_ancestors :none
    policy.font_src :self, :https, :data
    policy.img_src :self, :https, :data
    policy.object_src :none
    policy.script_src :self, :https
    policy.style_src :self, :https
    policy.connect_src :self, :https, "wss:"
  end

  # Generate a stable, non-empty nonce per request for script/style directives.
  config.content_security_policy_nonce_generator = lambda do |request|
    request.env["csp_nonce"] ||= SecureRandom.base64(16)
  end
  config.content_security_policy_nonce_directives = %w[script-src style-src]

  # Automatically add `nonce` to JavaScript and stylesheet tags.
  config.content_security_policy_nonce_auto = true
end
