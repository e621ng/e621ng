# frozen_string_literal: true

# Compatibility shim for tzdata 2025b (ubuntu24), where some IANA timezone
# identifiers were renamed. Rails 8.1 still maps to the old names.
#
# Relevant issues: https://github.com/rails/rails/issues/54999
#                  https://github.com/rails/rails/pull/51703
#
# Remove once fixed upstream and Rails version is bumped.
{ "Kyiv" => "Europe/Kyiv",
  "Bad Dragon" => "America/Phoenix", # small easter egg
  "Rangoon" => "Asia/Yangon", }.each do |name, tzinfo|
  if ActiveSupport::TimeZone::MAPPING[name] == tzinfo
    Rails.logger.warn("Timezone patch no longer needed for #{name} (#{__FILE__}:#{__LINE__})")
  else
    ActiveSupport::TimeZone::MAPPING[name] = tzinfo
  end
end
