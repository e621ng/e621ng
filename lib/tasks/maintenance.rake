# frozen_string_literal: true

namespace :maintenance do
  desc "Run daily maintenance jobs"
  task daily: :environment do
    Maintenance.daily
  end
end
