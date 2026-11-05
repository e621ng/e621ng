# frozen_string_literal: true

require "rails_helper"

RSpec.describe "IP spoofing check" do
  # At info, Rails::Rack::Logger reads remote_ip outside the controller's rescue_from. Production logs at error.
  around do |example|
    level = Rails.logger.level
    Rails.logger.level = :warn
    example.run
  ensure
    Rails.logger.level = level
  end

  it "rejects a Forwarded header that disagrees with X-Forwarded-For" do
    get news_updates_path, headers: { "X-Forwarded-For" => "203.0.113.9", "Forwarded" => "for=198.51.100.1" }
    expect(response).to have_http_status(:bad_request)
  end

  it "allows a Forwarded header that agrees with X-Forwarded-For" do
    get news_updates_path, headers: { "X-Forwarded-For" => "203.0.113.9", "Forwarded" => "for=203.0.113.9" }
    expect(response).to have_http_status(:ok)
  end

  it "rejects a Client-Ip header that disagrees with X-Forwarded-For" do
    get news_updates_path, headers: { "X-Forwarded-For" => "203.0.113.9", "Client-Ip" => "198.51.100.1" }
    expect(response).to have_http_status(:bad_request)
  end
end
