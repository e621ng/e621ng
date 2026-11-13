# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Content Security Policy" do
  subject(:script_src) do
    get furid_path
    header = response.headers["Content-Security-Policy"]
    header.split(";").map(&:strip).find { |directive| directive.start_with?("script-src ") }
  end

  it "sends a Content-Security-Policy header" do
    get furid_path
    expect(response.headers["Content-Security-Policy"]).to be_present
  end

  it "includes 'strict-dynamic' in script-src so the host allowlist is ignored by CSP3 browsers" do
    expect(script_src).to include("'strict-dynamic'")
  end

  it "includes a per-request nonce in script-src" do
    expect(script_src).to match(/'nonce-[^']+'/)
  end

  it "limits object-src to the static hosts" do
    get furid_path
    object_src = response.headers["Content-Security-Policy"].split(";").map(&:strip).find { |directive| directive.start_with?("object-src ") }
    expect(object_src.split).to contain_exactly("object-src", "static1.e621.net", "static1.e926.net")
  end
end
