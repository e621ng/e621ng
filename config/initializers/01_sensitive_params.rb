# frozen_string_literal: true

module SensitiveParams
  # Common values for Rails and Datadog query parameter filtering
  PARAMS = %i[passw secret token _key crypt salt certificate otp ssn email].freeze

  def self.to_datadog_regex
    Regexp.new("(?:#{PARAMS.join('|')})[^&]*=[^&]*")
  end
end
