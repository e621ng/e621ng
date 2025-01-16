# frozen_string_literal: true

Mailgun.configure do |config|
  config.api_key = Danbooru.config.mailgun_api_key
end
