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

    private

    def format_count(input, length: 6)
      input = input.to_i.clamp(0, (10**length) - 1) unless length == 0
      (ActiveSupport::NumberHelper.number_to_delimited(input) || "").rjust(length, " ")
    end

    def format_delta(diff, positive_good: false)
      if diff > 0
        operator = "▲"
        color = positive_good ? :green : :red
      elsif diff < 0
        operator = "▼"
        color = positive_good ? :red : :green
      else
        operator = " "
        color = :white
      end

      send("color_#{color}", "#{operator} #{format_count(diff.abs, length: 0)}".ljust(8, " "))
    end

    def color_bold(text)
      "\u001b[1m#{text}\u001b[0m"
    end

    def color_blue(text)
      "\u001b[1;36m#{text}\u001b[0m"
    end

    def color_green(text)
      "\u001b[0;32m#{text}\u001b[0m"
    end

    def color_red(text)
      "\u001b[0;31m#{text}\u001b[0m"
    end

    def color_white(text)
      "\u001b[1;37m#{text}\u001b[0m"
    end
  end
end
