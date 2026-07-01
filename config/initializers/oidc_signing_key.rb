# frozen_string_literal: true

require Rails.root.join("app/logical/oidc_signing_key")

OidcSigningKey.check! if Danbooru.config.enable_oauth_provider? && !Rails.env.test?
