# frozen_string_literal: true

module DiscordReport
  class Base
    def webhook_url
      raise NotImplementedError
    end

    def report
      raise NotImplementedError
    end

    def run!
      return if webhook_url.blank?

      post_webhook
    end

    def post_webhook
      conn = Faraday.new(Danbooru.config.faraday_options)
      conn.post(webhook_url, { content: report, flags: 4096 }.to_json, { content_type: "application/json" })
    end

    def formatted_number(input)
      "**#{ActiveSupport::NumberHelper.number_to_delimited(input)}**"
    end

    def more_fewer(diff)
      "#{formatted_number(diff.abs)} #{diff >= 0 ? 'more' : 'fewer'}"
    end
  end
end
