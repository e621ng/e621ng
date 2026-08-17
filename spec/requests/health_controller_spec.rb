# frozen_string_literal: true

require "rails_helper"

RSpec.describe "HealthController" do
  it "returns OK when the service is healthy" do
    get "/health"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("OK")
  end

  it "returns Service Unavailable when the service is out of rotation" do
    FileUtils.touch("tmp/out_of_rotation")
    get "/health"
    expect(response).to have_http_status(:service_unavailable)
    expect(response.body).to eq("Service Unavailable")
  ensure
    FileUtils.rm_f("tmp/out_of_rotation")
  end

  it "reads the drain file location from DANBOORU_DRAIN_FILE" do
    path = Rails.root.join("tmp/drain_file_spec").to_s
    ENV["DANBOORU_DRAIN_FILE"] = path
    FileUtils.touch(path)
    get "/health"
    expect(response).to have_http_status(:service_unavailable)
  ensure
    FileUtils.rm_f(path)
    ENV.delete("DANBOORU_DRAIN_FILE")
  end
end
