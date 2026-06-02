# frozen_string_literal: true

class HealthController < ApplicationController
  OUT_OF_ROTATION_FILE = Rails.root.join("tmp/out_of_rotation").freeze

  def index
    if OUT_OF_ROTATION_FILE.exist?
      render plain: "Service Unavailable", status: 503
      return
    end

    parts = ["OK"]
    parts << Danbooru.config.server_name if Danbooru.config.server_name.present?
    parts << GitHelper.version if GitHelper.version.present?
    render plain: parts.join(" | ")
  end
end
