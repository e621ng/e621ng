# frozen_string_literal: true

# "Firefox on Windows"-style labels for the Sessions page. Deliberately small:
# the major browsers and systems, everything else "Unknown browser". The raw
# user agent is shown alongside, so a miss costs nothing.
module UserAgentLabel
  UNKNOWN = "Unknown browser"

  # Order matters: Chromium-based browsers also advertise Chrome/Safari.
  BROWSERS = [
    ["Edge", %r{\bEdg(?:e|A|iOS)?/}],
    ["Opera", %r{\bOPR/|\bOpera\b}],
    ["Samsung Internet", %r{\bSamsungBrowser/}],
    ["Vivaldi", %r{\bVivaldi/}],
    ["Chrome", %r{\b(?:Chrome|CriOS|CrMo)/}],
    ["Firefox", %r{\b(?:Firefox|FxiOS)/}],
    ["Safari", %r{\bSafari/}],
    ["curl", %r{\Acurl/}],
    ["Python requests", %r{\Apython-requests/}],
    ["okhttp", %r{\Aokhttp/}],
  ].freeze

  SYSTEMS = [
    ["Windows", /\bWindows\b/],
    ["Android", /\bAndroid\b/],
    ["iPadOS", /\biPad\b/],
    ["iOS", /\biPhone\b|\biPod\b/],
    ["macOS", /\bMac OS X\b|\bMacintosh\b/],
    ["ChromeOS", /\bCrOS\b/],
    ["Linux", /\bLinux\b/],
  ].freeze

  def self.for(user_agent)
    ua = user_agent.to_s
    browser = BROWSERS.find { |_, pattern| ua.match?(pattern) }&.first
    system = SYSTEMS.find { |_, pattern| ua.match?(pattern) }&.first
    return UNKNOWN if browser.nil? && system.nil?
    [browser || UNKNOWN, system].compact.join(" on ")
  end
end
