# frozen_string_literal: true

module Sources
  module Alternates
    def self.all
      return [
        Alternates::Furaffinity,
        Alternates::Pixiv,
        Alternates::Deviantart,
        Alternates::Twitter,
        Alternates::Inkbunny,
        Alternates::Youtube,
        Alternates::Derpibooru,
      ]
    end

    def self.find(url, default: Alternates::Null)
      alternate = all.map {|alternate| alternate.new(url)}.detect(&:match?)
      alternate || default&.new(url)
    end
  end
end
