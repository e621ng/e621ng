# frozen_string_literal: true

class AsnRange < ApplicationRecord
  INSERT_BATCH_SIZE = 5_000

  # Resolves IP addresses to the ASN ranges containing them.
  # Takes strings or IPAddr objects and returns a hash with a key for every
  # parseable input: { "1.2.3.4" => { asn:, name:, country: } | nil }.
  # Private, loopback, and link-local addresses resolve to nil without
  # touching the database, as does everything when the table is empty.
  def self.lookup(ips)
    addrs = Array(ips).filter_map do |ip|
      IPAddr.new(ip.to_s)
    rescue IPAddr::InvalidAddressError
      nil
    end
    result = addrs.to_h { |ip| [ip.to_s, nil] }
    queryable = addrs.reject { |ip| ip.private? || ip.loopback? || ip.link_local? }
    return result if queryable.empty?

    # The ranges are non-overlapping and per-family (the inet btree orders all
    # of IPv4 below IPv6), so the containing range is always the one with the
    # greatest first_ip <= ip. The last_ip check must stay outside the lateral
    # subquery: inside it, an IP in a gap would walk the index all the way back.
    values = Array.new(queryable.size, "(?::inet)").join(", ")
    sql = sanitize_sql_array([<<~SQL.squish, *queryable.map(&:to_s)])
      SELECT v.ip, r.asn, r.name, r.country
      FROM (VALUES #{values}) AS v(ip)
      LEFT JOIN LATERAL (
        SELECT asn, name, country, last_ip
        FROM asn_ranges
        WHERE first_ip <= v.ip
        ORDER BY first_ip DESC
        LIMIT 1
      ) r ON r.last_ip >= v.ip
    SQL
    connection.select_all(sql).each do |row|
      next if row["asn"].nil?
      result[IPAddr.new(row["ip"].to_s).to_s] = { asn: row["asn"], name: row["name"], country: row["country"] }
    end
    result
  end

  # Replaces the whole dataset atomically; concurrent lookups keep seeing the
  # old rows until the transaction commits. Accepts any enumerable (including
  # a lazy enumerator) and inserts it in slices, so the full dataset never has
  # to be materialized. Yields the inserted row count while still inside the
  # transaction, letting callers validate the dataset and abort by raising.
  def self.replace_all!(rows)
    transaction do
      delete_all
      count = 0
      rows.each_slice(INSERT_BATCH_SIZE) do |slice|
        insert_all(slice)
        count += slice.size
      end
      yield count if block_given?
    end
  end
end
