# frozen_string_literal: true

# Fix for a timezone bug in Rails that causes specific timezones to not be recognized.
# This is not an issue in development (alpine3.20), nor on the old production servers (ubuntu20).
# However, it causes errors in the newly upgraded app4 server (ubuntu24).
#
# Relevant issues:
# https://github.com/rails/rails/issues/54999
# https://github.com/rails/rails/pull/51703
#
# This can be removed once the issue is patched in Rails.
{ "Kyiv" => "Europe/Kyiv",
  "Bad Dragon" => "America/Phoenix", # small easter egg
  "Rangoon" => "Asia/Yangon",
  "Greenland" => "America/Nuuk", }.each do |name, tzinfo|
  if ActiveSupport::TimeZone::MAPPING[name] == tzinfo
    warn("Timezone patch not necessary for #{name} at #{__FILE__}:#{__LINE__}")
  else
    ActiveSupport::TimeZone::MAPPING[name] = tzinfo
  end
end
