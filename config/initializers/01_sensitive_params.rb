# frozen_string_literal: true

module SensitiveParams
  # Common values for Rails and Datadog query parameter filtering
  PARAMS = %i[passw secret token _key crypt salt certificate otp ssn email].freeze
  # Matched only as the full parameter name; too generic for a partial match
  EXACT_PARAMS = %w[key].freeze

  def self.to_rails_filters
    PARAMS + EXACT_PARAMS.map { |name| /\A#{Regexp.escape(name)}\z/ }
  end

  def self.to_datadog_regex
    exact = EXACT_PARAMS.map { |name| Regexp.escape(name) }.join("|")
    # (?<![^&]) anchors to the start of the query or a preceding "&" without consuming it
    Regexp.new("(?<![^&])(?:#{exact})=[^&]*|(?:#{PARAMS.join('|')})[^&]*=[^&]*")
  end

  # Drops exact-match params from a path's query string, e.g. before nesting it in a return URL
  def self.strip_from_path(path)
    base, query = path.split("?", 2)
    return path if query.nil?
    kept = query.split("&").reject { |pair| EXACT_PARAMS.include?(pair.split("=", 2).first) }
    kept.empty? ? base : "#{base}?#{kept.join('&')}"
  end
end
