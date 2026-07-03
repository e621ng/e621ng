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
end
