# frozen_string_literal: true

require "rails_helper"

# Regression coverage for ApplicationController#sanitize_cookies.
#
# A request carrying a cookie whose URL-encoded value decodes to invalid UTF-8
# (e.g. `nmm=%FF`) used to crash while rendering the default layout: the head
# partial calls `disable_mobile_mode?`, which runs `cookies[:nmm].present?`, and
# String#blank? raises `ArgumentError: invalid byte sequence in UTF-8` on a
# string with invalid encoding. The ParameterSanitizer middleware only scrubs
# the still-encoded Cookie header, so the bad byte reappears once Rails decodes
# the value. sanitize_cookies scrubs the decoded jar to close that gap.
RSpec.describe "Cookie sanitization" do
  # Anonymous, HTML, renders the default layout (and thus disable_mobile_mode?).
  let(:path) { keyboard_shortcuts_path }

  it "renders without crashing when a cookie decodes to invalid UTF-8" do
    get path, headers: { "HTTP_COOKIE" => "nmm=%FF" }
    expect(response).to have_http_status(:ok)
  end

  it "renders without crashing when a cookie contains a null byte" do
    get path, headers: { "HTTP_COOKIE" => "nmm=%001" }
    expect(response).to have_http_status(:ok)
  end

  it "leaves a well-formed cookie value intact" do
    get path, headers: { "HTTP_COOKIE" => "nmm=1" }
    expect(response).to have_http_status(:ok)
  end
end
