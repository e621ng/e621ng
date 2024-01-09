module DiscordReport
  class Base
    def webhook_url
      raise NotImplementedError
    end

    def post_webhook(content)
      HTTParty.post(
        webhook_url,
        body: {
          content: content,
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
  end
end
