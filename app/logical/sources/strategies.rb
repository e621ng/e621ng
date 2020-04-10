module Sources
  module Strategies
    def self.all
      return [
        Strategies::PixivSlim
      ]
    end

    def self.find(url, referer=nil, default: Strategies::Null)
      strategy = all.map { |strategy| strategy.new(url, referer) }.detect(&:match?)
      strategy || default&.new(url, referer)
    end

    def self.canonical(url, referer)
      find(url, referer).canonical_url
    end
  end
end
