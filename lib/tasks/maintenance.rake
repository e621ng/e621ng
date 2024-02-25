# frozen_string_literal: true

require "tasks/newrelic" if defined?(NewRelic)

namespace :maintenance do
  desc "Run daily maintenance jobs"
  task daily: :environment do
    Maintenance.daily
  end
end
