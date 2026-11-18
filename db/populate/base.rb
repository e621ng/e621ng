# frozen_string_literal: true

require "faker"

# Development data generators. Each generator is a class with `call`; the rake
# tasks in lib/tasks/populate.rake read the environment and build the options.
module Populate
  DEFAULT_PASSWORD = "hexerade"
  LOCAL_IP = "127.0.0.1"

  def self.setup_current_user!
    CurrentUser.user = User.find(1)
    CurrentUser.ip_addr = LOCAL_IP
  end

  class Base
    attr_reader :options

    def initialize(**options)
      @options = options
    end

    def call
      raise NotImplementedError
    end

    private

    def log(message)
      puts message
    end

    def distribution
      options.fetch(:distribution, 10)
    end

    # Users old enough to have passed the new-account restrictions.
    def random_users(older_than: 14.days, limit: distribution)
      User.where(created_at: ...older_than.ago).limit(limit).order("random()")
    end

    def random_posts(limit: distribution)
      Post.limit(limit).order("random()")
    end

    def paragraph
      Faker::Hipster.paragraph_by_chars(characters: rand(100..2_000), supplemental: false)
    end
  end
end
