# frozen_string_literal: true

# Downloads the iptoasn.com dataset and replaces the asn_ranges table with it.
module AsnRangeImporter
  class Error < StandardError; end

  # The full dataset has ~500k routed ranges; refuse to swap in anything small
  # enough to indicate a truncated or corrupt download.
  MINIMUM_ROW_COUNT = 100_000

  def self.import!
    url = Danbooru.config.ip_to_asn_data_url
    return if url.blank?

    options = Danbooru.config.faraday_options.deep_merge(request: { timeout: 60 })
    response = Faraday.new(options).get(url)
    raise Error, "Failed to download ip2asn data: HTTP #{response.status}" unless response.success?

    AsnRange.replace_all!(parse(response.body)) do |count|
      # Raising here rolls the whole swap back, restoring the previous dataset.
      raise Error, "Refusing to import suspiciously small dataset (#{count} rows)" if count < MINIMUM_ROW_COUNT
    end
  end

  # TSV columns: range_start, range_end, AS_number, country_code, AS_description.
  # AS 0 marks unrouted space and is skipped; the literal country "None" means
  # unknown and is normalized to an empty string.
  # Returns an enumerator so the ~500k rows are never all in memory at once.
  def self.parse(gz_data)
    Enumerator.new do |yielder|
      Zlib::GzipReader.new(StringIO.new(gz_data)).each_line do |line|
        first_ip, last_ip, asn, country, name = line.chomp.split("\t", 5)
        next if asn.to_i == 0

        country = "" if country == "None"
        yielder << { first_ip: first_ip, last_ip: last_ip, asn: asn.to_i, country: country, name: name }
      end
    end
  end
end
