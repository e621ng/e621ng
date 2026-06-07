# frozen_string_literal: true

# rubocop:disable Rails/Output

module FavStats
  C   = ApplicationRecord.connection
  CAP = 80_000 # default favorite_limit; only used to label the "near cap" line
  F   = ->(n) { n.to_i.to_s.gsub(/\B(?=(\d{3})+(?!\d))/, ",") }

  def self.h(text) = puts("\n\e[1m== #{text} ==\e[0m")

  def self.run
    distribution
    catalog_stats
    analyze_health
    plans
    seq_scans
    seq_scan_culprits
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

    near = (CAP * 0.9).to_i
    h "How many users are within 10% of the #{F[CAP]} cap"
    n = C.select_value("SELECT count(*) FROM user_statuses WHERE favorite_count >= #{near}")
    puts "  users >= #{F[near]} favs : #{F[n]}   (the population a higher cap would release)"
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
    est       = C.select_value("SELECT n_distinct FROM pg_stats WHERE tablename='favorites' AND attname='user_id'").to_f
    actual    = C.select_value("SELECT count(*) FROM user_statuses WHERE favorite_count > 0").to_i
    reltuples = C.select_value("SELECT reltuples::bigint FROM pg_class WHERE relname='favorites'").to_i
    shown = est < 0 ? "ratio #{est} (manual override)" : (F[est.to_i]).to_s
    puts "  → user_id n_distinct estimate: #{shown}"
    puts "  → actual distinct favoriting users (proxy): #{F[actual]}"
    # The ratio MUST divide by THIS table's row count, not a constant — otherwise it
    # rounds to a useless value on smaller instances (e6AI's 19M-row table gave -0.0).
    if est >= 0 && reltuples > 0 && est < actual * 0.5
      ratio = [(actual.to_f / reltuples).round(4), 0.0001].max
      puts "  → estimate far below actual; consider: " \
           "ALTER TABLE favorites ALTER COLUMN user_id SET (n_distinct = -#{ratio}); ANALYZE favorites;"
    end
  end

  # Is autoanalyze keeping up?
  def self.analyze_health
    h "ANALYZE / autovacuum health for favorites"
    r = C.select_one(<<~SQL.squish)
      SELECT n_live_tup, n_dead_tup, n_mod_since_analyze, last_analyze, last_autoanalyze,
             (SELECT reloptions FROM pg_class WHERE relname='favorites') AS reloptions
      FROM pg_stat_user_tables WHERE relname='favorites'
    SQL
    live = r["n_live_tup"].to_i
    mods = r["n_mod_since_analyze"].to_i
    # Read the REAL scale factor from reloptions; fall back to the cluster default of 0.1.
    scale = (r["reloptions"].to_s[/analyze_scale_factor=([0-9.]+)/, 1] || "0.1").to_f
    threshold = (50 + (scale * live)).to_i
    puts "  n_live_tup           : #{F[live]}"
    puts "  n_dead_tup           : #{F[r['n_dead_tup']]}"
    puts "  n_mod_since_analyze  : #{F[mods]}"
    puts "  last_analyze         : #{r['last_analyze'] || '(never)'}"
    puts "  last_autoanalyze     : #{r['last_autoanalyze'] || '(never)'}"
    puts "  autoanalyze trigger (~#{(scale * 100).round(2)}%): #{F[threshold]} modifications"
    puts "  table reloptions     : #{r['reloptions'] || '(defaults)'}"
    puts "  ⚠ #{F[mods]} mods since last analyze, #{F[threshold - mods]} short of the next autoanalyze" if mods > 0 && mods < threshold
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
      SELECT seq_scan, idx_scan, seq_tup_read, n_live_tup FROM pg_stat_user_tables WHERE relname='favorites'
    SQL
    puts "  seq_scan=#{F[r['seq_scan']]}  idx_scan=#{F[r['idx_scan']]}  seq_tup_read=#{F[r['seq_tup_read']]}"
    puts "  ⚠ #{F[r['seq_scan']]} seq scans on a #{F[r['n_live_tup']]}-row table — run seq_scan_culprits to find the source" if r["seq_scan"].to_i > 100
  end

  # Identify which statements are doing the sequential reads on favorites.
  # Requires the pg_stat_statements extension (shared_preload_libraries + CREATE EXTENSION).
  def self.seq_scan_culprits(limit: 20)
    h "Statements touching 'favorites', ranked by disk reads (needs pg_stat_statements)"
    unless C.select_value("SELECT to_regclass('pg_stat_statements') IS NOT NULL")
      puts "  pg_stat_statements is not available."
      puts "  Enable it (shared_preload_libraries=pg_stat_statements + restart), then: CREATE EXTENSION pg_stat_statements;"
      return
    end

    # NOTE: no `--` comments inside this heredoc; .squish collapses newlines and would
    # comment out the rest of the statement. The pg_st% filter drops catalog/introspection
    # queries (including this utility's own).
    rows = C.select_all(<<~SQL.squish)
      SELECT calls,
             round(total_exec_time)   AS total_ms,
             round(mean_exec_time::numeric, 2) AS mean_ms,
             shared_blks_read         AS blks_read,
             shared_blks_hit          AS blks_hit,
             rows,
             regexp_replace(left(query, 160), '\\s+', ' ', 'g') AS query
      FROM pg_stat_statements
      WHERE query ILIKE '%favorites%' AND query NOT ILIKE '%pg_st%'
      ORDER BY shared_blks_read DESC
      LIMIT #{limit.to_i}
    SQL

    if rows.empty?
      puts "  No statements mentioning 'favorites' found (stats may have been reset)."
      return
    end

    rows.each do |row|
      puts "  ─────"
      puts "  calls=#{F[row['calls']]}  total=#{F[row['total_ms']]}ms  mean=#{row['mean_ms']}ms  " \
           "blks_read=#{F[row['blks_read']]}  blks_hit=#{F[row['blks_hit']]}  rows=#{F[row['rows']]}"
      puts "  #{row['query']}"
    end
    puts "\n  → high blks_read + low calls = a heavy scanner; that's your seq-scan source"
    puts "  → high calls + low mean_ms   = healthy indexed traffic, ignore"
    puts "  → for a fresh measurement window: SELECT pg_stat_statements_reset();"
  rescue ActiveRecord::StatementInvalid => e
    puts "  Could not query pg_stat_statements: #{e.message.lines.first&.strip}"
  end
end

# rubocop:enable Rails/Output

FavStats.run
