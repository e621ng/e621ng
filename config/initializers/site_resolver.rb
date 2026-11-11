# frozen_string_literal: true

# Inside RequestStore's middleware so the resolved site is cleared after each
# request. RequestStore adds its middleware from a railtie initializer, so this
# can't live in config/application.rb.
Rails.application.config.middleware.insert_after RequestStore::Middleware, Middleware::SiteResolver
