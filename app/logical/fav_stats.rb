# frozen_string_literal: true

# rubocop:disable Rails/Output

module FavStats
  C = ApplicationRecord.connection
  F = ->(n) { n.to_i.to_s.gsub(/\B(?=(\d{3})+(?!\d))/, ",") }

  def self.h(text) = puts("\n\e[1m== #{text} ==\e[0m")

  def self.run
    distribution
    catalog_stats
    analyze_health
    plans
    seq_scans
    nil
  end

  # Per-user fav-count distribution — read from the counter cache, NOT a GROUP BY on favorites.
  def self.distribution
    h "Per-user favorite_count distribution (from user_statuses)"
    row = C.select_one(<<~SQL.squish)
      SELECT
        count(*)                                                    AS users,
        count(*) FILTER (WHERE favorite_count > 0)                  AS users_with_favs,
        max(favorite_count)                                         AS max,
        round(avg(favorite_count) FILTER (WHERE favorite_count > 0), 1) AS avg_active,
        percentile_disc(0.50) WITHIN GROUP (ORDER BY favorite_count) AS p50,
        percentile_disc(0.90) WITHIN GROUP (ORDER BY favorite_count) AS p90,
        percentile_disc(0.99) WITHIN GROUP (ORDER BY favorite_count) AS p99,
        percentile_disc(0.999) WITHIN GROUP (ORDER BY favorite_count) AS p999
      FROM user_statuses
    SQL
    puts "  users                : #{F[row['users']]}"
    puts "  users with >0 favs   : #{F[row['users_with_favs']]}"
    puts "  max favorites        : #{F[row['max']]}"
    puts "  avg (active users)   : #{row['avg_active']}"
    puts "  p50 / p90 / p99 / p999: #{F[row['p50']]} / #{F[row['p90']]} / #{F[row['p99']]} / #{F[row['p999']]}"

    h "Users at/near the cap (top 20)"
    C.select_all(<<~SQL.squish).each { |r| puts "  user_id=#{r['user_id']}  favs=#{F[r['favorite_count']]}" }
      SELECT user_id, favorite_count FROM user_statuses
      ORDER BY favorite_count DESC LIMIT 20
    SQL

    h "How many users are within 10% of the 80k cap"
    n = C.select_value("SELECT count(*) FROM user_statuses WHERE favorite_count >= 72000")
    puts "  users >= 72,000 favs : #{F[n]}   (these are who a 100k bump actually affects)"
  end

  # What the planner believes about the favorites columns.
  def self.catalog_stats
    h "pg_stats for favorites (what the planner believes)"
    C.select_all(<<~SQL.squish).each do |r|
      SELECT attname, n_distinct, correlation,
             array_length(most_common_vals::text::text[], 1) AS mcv_entries,
             (SELECT max(f) FROM unnest(most_common_freqs) f) AS top_mcv_freq
      FROM pg_stats
      WHERE tablename = 'favorites' AND attname IN ('user_id','post_id')
    SQL
      puts "  #{r['attname'].ljust(8)} n_distinct=#{r['n_distinct']}  correlation=#{r['correlation']}  " \
           "mcv_entries=#{r['mcv_entries'] || 0}  top_mcv_freq=#{r['top_mcv_freq']}"
    end
    est = C.select_value("SELECT n_distinct FROM pg_stats WHERE tablename='favorites' AND attname='user_id'").to_f
    actual = C.select_value("SELECT count(*) FROM user_statuses WHERE favorite_count > 0").to_i
    shown = est < 0 ? "ratio #{est} (manual override)" : (F[est.to_i]).to_s
    puts "  → user_id n_distinct estimate: #{shown}"
    puts "  → actual distinct favoriting users (proxy): #{F[actual]}"
    puts "  → if the estimate is far below actual, SET (n_distinct = -#{(actual / 1_300_000_000.0).round(4)}) on user_id" if est >= 0 && est < actual * 0.5
  end

  # Is autoanalyze keeping up on a 1.3B-row table?
  def self.analyze_health
    h "ANALYZE / autovacuum health for favorites"
    r = C.select_one(<<~SQL.squish)
      SELECT n_live_tup, n_dead_tup, n_mod_since_analyze, last_analyze, last_autoanalyze,
             (SELECT reloptions FROM pg_class WHERE relname='favorites') AS reloptions
      FROM pg_stat_user_tables WHERE relname='favorites'
    SQL
    live = r["n_live_tup"].to_i
    threshold = 50 + (0.1 * live) # default analyze_threshold + scale_factor * live
    puts "  n_live_tup           : #{F[live]}"
    puts "  n_dead_tup           : #{F[r['n_dead_tup']]}"
    puts "  n_mod_since_analyze  : #{F[r['n_mod_since_analyze']]}"
    puts "  last_analyze         : #{r['last_analyze'] || '(never)'}"
    puts "  last_autoanalyze     : #{r['last_autoanalyze'] || '(never)'}"
    puts "  default autoanalyze threshold (~10%): #{F[threshold.to_i]} modifications"
    puts "  table reloptions     : #{r['reloptions'] || '(defaults)'}"
    puts "  ⚠ stats may be stale: #{F[r['n_mod_since_analyze']]} mods vs trigger at ~#{F[threshold.to_i]}" \
      if r["n_mod_since_analyze"].to_i > 0 && r["n_mod_since_analyze"].to_i < threshold * 0.5
  end

  # Estimate-vs-actual on the queries the app actually runs, for a whale and a typical user.
  def self.plans
    whale = C.select_value("SELECT user_id FROM user_statuses ORDER BY favorite_count DESC LIMIT 1")
    p50   = C.select_value("SELECT percentile_disc(0.5) WITHIN GROUP (ORDER BY favorite_count) FROM user_statuses WHERE favorite_count > 0")
    typ   = C.select_value("SELECT user_id FROM user_statuses WHERE favorite_count >= #{p50.to_i} ORDER BY favorite_count LIMIT 1")

    { "WHALE user_id=#{whale}" => whale, "TYPICAL user_id=#{typ}" => typ }.each do |label, uid|
      next unless uid
      h "EXPLAIN ANALYZE — favorites list query (#{label})"
      sql = "SELECT * FROM favorites WHERE user_id = #{uid.to_i} ORDER BY created_at DESC LIMIT 75"
      puts C.select_values("EXPLAIN (ANALYZE, BUFFERS) #{sql}").map { |l| "  #{l}" }.join("\n")
    end
    puts "\n  → compare 'rows=' (estimated) vs 'actual rows=' on each node; >10x gap = stats problem"
    puts "  → confirm it's an Index Scan using index_favorites_on_user_id_and_created_at, not a Sort"
  end

  def self.seq_scans
    h "Scan counts on favorites (loud alarm if seq scans grow)"
    r = C.select_one(<<~SQL.squish)
      SELECT seq_scan, idx_scan, seq_tup_read FROM pg_stat_user_tables WHERE relname='favorites'
    SQL
    puts "  seq_scan=#{F[r['seq_scan']]}  idx_scan=#{F[r['idx_scan']]}  seq_tup_read=#{F[r['seq_tup_read']]}"
    puts "  ⚠ non-trivial seq_scan on a 1.3B-row table is a red flag" if r["seq_scan"].to_i > 100
  end
end

# rubocop:enable Rails/Output
