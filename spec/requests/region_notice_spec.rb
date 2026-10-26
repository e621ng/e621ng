# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Region notice" do
  let(:path) { keyboard_shortcuts_path }
  let(:tos_cookie) { "tos_accepted=#{Setting.tos_version}" }

  def visit(country: nil, cookies: [tos_cookie], params: {})
    headers = { "HTTP_COOKIE" => cookies.join("; ") }
    headers["CF-IPCountry"] = country if country
    get path, params: params, headers: headers
    expect(response).to have_http_status(:ok)
  end

  def notice_rendered?
    response.body.include?('id="region-notice"')
  end

  it "is shown to visitors from a configured country" do
    visit(country: "GB")
    expect(notice_rendered?).to be(true)
  end

  it "matches the country code case-insensitively" do
    visit(country: "gb")
    expect(notice_rendered?).to be(true)
  end

  it "is not shown to visitors from other countries" do
    visit(country: "US")
    expect(notice_rendered?).to be(false)
  end

  it "is not shown when the country header is missing" do
    visit
    expect(notice_rendered?).to be(false)
  end

  it "is not shown once dismissed" do
    visit(country: "GB", cookies: [tos_cookie, "hide_region_notice=1"])
    expect(notice_rendered?).to be(false)
  end

  it "is not shown while the TOS modal is pending" do
    visit(country: "GB", cookies: [])
    expect(notice_rendered?).to be(false)
  end

  it "is not shown when no countries are configured" do
    allow(Danbooru.config.custom_configuration).to receive(:region_notice_countries).and_return([])
    visit(country: "GB")
    expect(notice_rendered?).to be(false)
  end

  describe "manual trigger" do
    it "shows the notice regardless of country, dismissal, or TOS state" do
      visit(cookies: ["hide_region_notice=1"], params: { region_notice: "1" })
      expect(notice_rendered?).to be(true)
    end
  end
end
