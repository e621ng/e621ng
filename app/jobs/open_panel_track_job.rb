# frozen_string_literal: true

class OpenPanelTrackJob < ApplicationJob
  # Metrics aren't worth retrying for days during an OpenPanel outage
  sidekiq_options queue: "low_prio", retry: 5

  def perform(name, properties)
    OpenPanelClient.track(name, properties)
  end
end
