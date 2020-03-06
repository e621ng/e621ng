# Be sure to restart your server when you modify this file.

Rails.application.config.session_store :cookie_store, key: '_danbooru_session'
Rails.application.config.action_dispatch.cookies_same_site_protection = :lax
