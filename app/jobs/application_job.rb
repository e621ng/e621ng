# frozen_string_literal: true

class ApplicationJob
  include Sidekiq::Job

  class JobError < StandardError; end
end
