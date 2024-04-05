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
      HTTParty.post(
        webhook_url,
        body: {
          content: report,
          flags: 4096,
        }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )
    end

    def formatted_number(input)
      "**#{ActiveSupport::NumberHelper.number_to_delimited(input)}**"
    end

    def more_fewer(diff)
      "#{formatted_number(diff.abs)} #{diff >= 0 ? 'more' : 'fewer'}"
    end
  end
end
