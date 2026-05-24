# frozen_string_literal: true

require Rails.root.join("app/logical/oidc_signing_key")

OidcSigningKey.check! unless Rails.env.test?
