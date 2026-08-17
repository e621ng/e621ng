# frozen_string_literal: true

class HealthController < ApplicationController
  def index
    if drain_file.exist?
      render plain: "Service Unavailable", status: 503
      return
    end

    parts = ["OK"]
    parts << Danbooru.config.server_name if Danbooru.config.server_name.present?
    parts << GitHelper.version if GitHelper.version.present?
    render plain: parts.join(" | ")
  end

  private

  # Containerized hosts point this at a read-only host mount so drain state
  # survives container replacement; elsewhere it stays inside the checkout.
  def drain_file
    Pathname.new(ENV["DANBOORU_DRAIN_FILE"] || Rails.root.join("tmp/out_of_rotation"))
  end
end
