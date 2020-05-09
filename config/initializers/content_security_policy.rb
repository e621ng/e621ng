# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy
# For further information see the following documentation
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy

 Rails.application.config.content_security_policy do |policy|
   policy.default_src :self
   policy.script_src  :self, 'ads.dragonfru.it', 'js-agent.newrelic.com', 'bam.nr-data.net', 'https://www.google.com/recaptcha/', 'https://www.gstatic.com/recaptcha/', 'https://www.recaptcha.net/', 'https://mc.yandex.ru/', 'https://yastatic.net'
   policy.style_src   :self, :unsafe_inline
   policy.connect_src :self, 'ads.dragonfru.it', 'bam.nr-data.net', 'https://mc.yandex.ru', 'https://yastatic.net'
   policy.object_src  :self, 'static1.e621.net', 'static1.e926.net'
   policy.media_src   :self, 'static1.e621.net', 'static1.e926.net'
   policy.frame_ancestors :none
   policy.frame_src   'https://www.google.com/recaptcha/', 'https://www.recaptcha.net/'
   policy.font_src    :self
   policy.img_src     :self, :data, 'static1.e621.net', 'static1.e926.net', 'ads.dragonfru.it', 'https://mc.yandex.ru', 'https://yastatic.net'
   policy.child_src   :none
   policy.form_action :self, 'discord.e621.net', 'discord.com'
#   # If you are using webpack-dev-server then specify webpack-dev-server host
#   policy.connect_src :self, :https, "http://localhost:3035", "ws://localhost:3035" if Rails.env.development?

#   # Specify URI for violation reports
# policy.report_uri "/csp-violation"
 end

# If you are using UJS then enable automatic nonce generation
 Rails.application.config.content_security_policy_nonce_generator = -> request { SecureRandom.base64(16) }

# Set the nonce only to specific directives
 Rails.application.config.content_security_policy_nonce_directives = %w(script-src)

# Report CSP violations to a specified URI
# For further information see the following documentation:
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy-Report-Only
 Rails.application.config.content_security_policy_report_only = false
