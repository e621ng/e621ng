# frozen_string_literal: true

module Sources
  module Strategies
    def self.all
      [
        Strategies::PixivSlim
      ]
    end

    def self.find(url, default: Strategies::Null)
      strategy = all.map { |strategy_class| strategy_class.new(url) }.detect(&:match?)
      strategy || default&.new(url)
    end
  end
end
