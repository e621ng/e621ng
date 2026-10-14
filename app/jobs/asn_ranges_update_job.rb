# frozen_string_literal: true

class AsnRangesUpdateJob < ApplicationJob
  sidekiq_options queue: "low_prio"

  def perform
    AsnRangeImporter.import!
  end
end
