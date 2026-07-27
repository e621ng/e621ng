# frozen_string_literal: true

class AsnRangesUpdateJob < ApplicationJob
  queue_as :low_prio

  def perform
    AsnRangeImporter.import!
  end
end
