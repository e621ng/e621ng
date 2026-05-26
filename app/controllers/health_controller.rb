# frozen_string_literal: true

class HealthController < ApplicationController
  def index
    if File.exist?("tmp/out_of_rotation")
      render plain: "Service Unavailable", status: 503
      return
    end
    render plain: "OK"
  end
end
