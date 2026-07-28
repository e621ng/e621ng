# frozen_string_literal: true

# Given a target user, ranks candidate alt accounts by shared-network evidence
# drawn from the user_ip_addresses aggregate table. Never exposes IP values;
# callers receive scores and IP-derived evidence only.
#
# Scoring, per shared value x (exact IP, or subnet):
#   contribution = rarity × proximity × dwell × confidence × weight
#
# contributions are grouped per ASN (siblings add log2 weight, crowded pools are
# sqrt-discounted), the top-5 groups summed into evidence, then
#   score = evidence × (0.3 + 0.7·√ratio) + handoff_bonus
# normalized to 0-100 against a configured saturation point.
class UserAltFinder
  DWELL_FULL_DAYS    = 14.0
  ASN_SIBLING_WEIGHT = 0.15
  ASN_CROWD_FREE     = 10
  TOP_K              = 5
  RATIO_FLOOR        = 0.3
  HANDOFF_DAYS       = 14.0
  HANDOFF_BONUS      = 1.5
  CHAIN_MIN_SCORE    = 2.0   # displayed-score threshold for chain expansion
  CHAIN_FANOUT       = 3     # at most this many direct candidates expanded
  CHAIN_RESULTS      = 3     # indirect candidates surfaced per expanded base

  def initialize(user, window: nil, chain: true)
    @user = user
    @cutoff = (window || Danbooru.config.user_ip_retention_period).ago
    @chain = chain
  end

  # Direct candidates, highest score first.
  def candidates
    analysis[:candidates]
  end

  # [{ via: <direct candidate>, candidates: [<indirect candidate>, ...] }].
  # Evasion chains (A -> B -> C, where A and C never shared an IP) are invisible to a
  # single-hop lookup; each base is re-analyzed and its fresh matches surfaced.
  def chains
    return @chains if defined?(@chains)
    @chains = @chain ? build_chains : []
  end

  private

  def analysis
    @analysis ||= analyze(@user)
  end

  def build_chains
    known = [@user.id] + analysis[:candidates].pluck(:user_id)
    bases = analysis[:candidates].select { |c| c[:score] >= CHAIN_MIN_SCORE }.first(CHAIN_FANOUT)
    bases.filter_map do |base|
      next unless base[:user]
      indirect = analyze(base[:user])[:candidates]
                 .reject { |c| known.include?(c[:user_id]) }
                 .first(CHAIN_RESULTS)
      { via: base, candidates: indirect } if indirect.any?
    end
  end

  # Full pipeline for one user: collect the target's footprint, measure rarity,
  # drop crowded values, join survivors, score. Reused per chain hop.
  def analyze(target)
    target_ips = collect_target_ips(target.id)
    return empty_result if target_ips.empty?

    target_subnets = aggregate_subnets(target_ips)
    ip_keys = target_ips.keys
    subnet_keys = target_subnets.keys

    users_per_ip = distinct_user_counts(:ip_addr, ip_keys)
    users_per_subnet = distinct_user_counts(:subnet, subnet_keys)
    crowded_ips = users_per_ip.select { |_, n| n > max_users_per_ip }.keys.to_set
    crowded_subnets = users_per_subnet.select { |_, n| n > max_users_per_subnet }.keys.to_set

    exact_rows = match_rows(:ip_addr, ip_keys, target.id)
    subnet_rows = match_rows(:subnet, subnet_keys, target.id)

    asn_map = resolve_asns(ip_keys, subnet_keys)

    score_candidates(
      target: target, target_ips: target_ips, target_subnets: target_subnets,
      exact_rows: exact_rows, subnet_rows: subnet_rows,
      users_per_ip: users_per_ip, users_per_subnet: users_per_subnet,
      crowded_ips: crowded_ips, crowded_subnets: crowded_subnets,
      asn_map: asn_map, co_users_per_asn: count_co_users_per_asn(exact_rows, subnet_rows, asn_map)
    )
  end

  def empty_result
    { candidates: [] }
  end

  # --- data collection (all against user_ip_addresses) ----------------------

  # { ip_string => { first:, last:, hits:, subnet: <cidr string> } }, capped to
  # the most-recently-seen rows.
  def collect_target_ips(user_id)
    rows = UserIpAddress
           .where(user_id: user_id)
           .where(last_seen_at: @cutoff..)
           .order(last_seen_at: :desc)
           .limit(target_ip_cap)
           .pluck(:ip_addr, :subnet, :first_seen_at, :last_seen_at, :hit_count)
    rows.each_with_object({}) do |(ip, subnet, first, last, hits), acc|
      acc[ip.to_s] = { first: first, last: last, hits: hits, subnet: cidr(subnet) }
    end
  end

  # { subnet_cidr => { first:, last:, hits: } } aggregated from the target's IPs.
  def aggregate_subnets(target_ips)
    target_ips.each_with_object({}) do |(_ip, v), acc|
      entry = acc[v[:subnet]] ||= { first: v[:first], last: v[:last], hits: 0 }
      entry[:first] = [entry[:first], v[:first]].min
      entry[:last]  = [entry[:last], v[:last]].max
      entry[:hits] += v[:hits]
    end
  end

  # COUNT(DISTINCT user_id) grouped by the value — index-only on the composite
  # (value, user_id) indexes. Keyed by canonical string.
  def distinct_user_counts(column, values)
    return {} if values.empty?
    UserIpAddress.where(column => values)
                 .group(column).distinct.count(:user_id)
                 .transform_keys { |k| canonical(column, k) }
  end

  # Other users' rows on the target's values. Merges to one entry per (user,
  # value). Keyed by canonical string.
  def match_rows(column, values, target_id)
    return {} if values.empty?
    rows = UserIpAddress.where(column => values).where.not(user_id: target_id)
                        .pluck(:user_id, column, :first_seen_at, :last_seen_at, :hit_count)
    result = Hash.new { |h, k| h[k] = [] }
    rows.each do |uid, value, first, last, hits|
      result[[uid, canonical(column, value)]] << { first: first, last: last, hits: hits }
    end
    result.map do |(uid, value), entries|
      { user_id: uid, value: value,
        first: entries.pluck(:first).min, last: entries.pluck(:last).max,
        hits: entries.sum { |e| e[:hits] }, }
    end
  end

  # Distinct co-users per ASN across ALL the target's matches (including
  # crowd-dropped values) — the pool-vs-residential discriminator.
  def count_co_users_per_asn(exact_rows, subnet_rows, asn_map)
    co_users = Hash.new { |h, k| h[k] = Set.new }
    exact_rows.each { |r| co_users[asn_group_for(r[:value], asn_map)] << r[:user_id] }
    subnet_rows.each { |r| co_users[asn_group_for(r[:value], asn_map)] << r[:user_id] }
    co_users.transform_values(&:size)
  end

  # --- scoring --------------------------------------------------------------

  # `data` carries everything analyze() computed (target, footprint, match rows,
  # rarity counts, crowded sets, asn_map, co_users_per_asn).
  def score_candidates(data)
    by_user = Hash.new { |h, k| h[k] = { exact: [], subnet: [] } }
    asn_map = data[:asn_map]

    data[:exact_rows].each do |r|
      next if data[:crowded_ips].include?(r[:value])
      e = evidence(r[:value], data[:target_ips][r[:value]], r, data[:users_per_ip][r[:value]], weight_exact)
      # The subnet this exact IP sits in, so the subnet loop below can dedupe
      # against it (a candidate's own row always matches its containing subnet).
      e[:subnet] = subnet_cidr_for_ip(r[:value])
      e[:asn_group] = asn_group_for(r[:value], asn_map)
      e[:asn] = asn_map[r[:value]]
      by_user[r[:user_id]][:exact] << e
    end

    data[:subnet_rows].each do |r|
      subnet = r[:value]
      next if data[:crowded_subnets].include?(subnet)
      # Skip if this candidate already matched an exact IP inside the subnet:
      # that network is already counted, more strongly, as exact evidence.
      next if by_user.key?(r[:user_id]) && by_user[r[:user_id]][:exact].any? { |e| e[:subnet] == subnet }
      e = evidence(subnet, data[:target_subnets][subnet], r, data[:users_per_subnet][subnet], subnet_weight(subnet))
      e[:subnet] = subnet
      e[:asn_group] = asn_group_for(subnet, asn_map)
      e[:asn] = asn_map[subnet]
      by_user[r[:user_id]][:subnet] << e
    end

    prelim = by_user.filter_map do |uid, ev|
      all = (ev[:exact] + ev[:subnet]).sort_by { |e| -e[:contribution] }
      groups = build_groups(all, data[:co_users_per_asn])
      evidence_sum = groups.first(TOP_K).sum { |g| g[:contribution] }
      { user_id: uid, evidence_sum: evidence_sum, exact: ev[:exact], subnet: ev[:subnet], all: all, groups: groups } if evidence_sum > 0
    end

    shortlist = prelim.sort_by { |c| -c[:evidence_sum] }.first(candidate_cap)
    finalize(shortlist, data[:target])
  end

  # Overlap ratio + handoff check for the shortlist, then the final score.
  def finalize(shortlist, target)
    users = User.where(id: shortlist.pluck(:user_id)).index_by(&:id)
    totals = shortlist.any? ? UserIpAddress.where(user_id: shortlist.pluck(:user_id)).group(:user_id).count : {}

    shortlist.each do |c|
      c[:user] = users[c[:user_id]]
      shared = c[:exact].size
      c[:total_ips] = [totals[c[:user_id]] || shared, shared].max
      ratio = shared > 0 ? shared.to_f / c[:total_ips] : 0.0
      ratio_factor = RATIO_FLOOR + ((1 - RATIO_FLOOR) * Math.sqrt([ratio, 1.0].min))
      c[:handoff] = c[:user] ? handoff?(target, c[:user], c[:exact]) : false
      raw = (c[:evidence_sum] * ratio_factor) + (c[:handoff] ? HANDOFF_BONUS : 0)
      c[:score] = [100.0 * raw / saturation, 100.0].min.round(1)
      annotate_display!(c)
    end

    { candidates: shortlist.reject { |c| c[:user].nil? }.sort_by { |c| -c[:score] } }
  end

  # Fields the view/blueprint read; never includes IP or subnet values.
  def annotate_display!(candidate)
    all = candidate[:all]
    candidate[:shared_exact] = candidate[:exact].size
    candidate[:shared_subnet] = candidate[:subnet].size
    candidate[:asn_groups] = candidate[:groups].size
    candidate[:pool_discounted] = candidate[:groups].count { |g| g[:crowd_factor] < 1.0 }
    candidate[:rarest_users] = all.pluck(:n_users).min
    candidate[:ratio] = candidate[:total_ips] > 0 ? (candidate[:shared_exact].to_f / candidate[:total_ips]) : 0.0
    candidate[:last_co_seen] = all.map { |e| [e[:mine][:last], e[:theirs][:last]].min }.max
    # Span of shared-value activity across both accounts (always a valid range;
    # the concurrent flag says whether their windows actually overlapped).
    candidate[:overlap_first] = all.flat_map { |e| [e[:mine][:first], e[:theirs][:first]] }.min
    candidate[:overlap_last] = all.flat_map { |e| [e[:mine][:last], e[:theirs][:last]] }.max
    candidate[:concurrent] = all.any? { |e| e[:mine][:first] <= e[:theirs][:last] && e[:theirs][:first] <= e[:mine][:last] }
    candidate[:deleted] = deleted?(candidate[:user])
  end

  def evidence(value, mine, theirs, n_users, weight)
    rarity = 1.0 / Math.log2(1 + n_users)
    gap_days = [([mine[:first], theirs[:first]].max - [mine[:last], theirs[:last]].min) / 1.day, 0.0].max
    prox = 0.5**(gap_days / proximity_half_life)
    spans = [mine, theirs].map { |w| (w[:last] - w[:first]) / 1.day }
    dwell = 0.5 + (0.5 * [spans.min / DWELL_FULL_DAYS, 1.0].min)
    conf = (0.4 + (0.3 * Math.log10(1 + [mine[:hits], theirs[:hits]].min))).clamp(0.0, 1.0)
    { value: value, n_users: n_users, mine: mine, theirs: theirs,
      contribution: rarity * prox * dwell * conf * weight, }
  end

  # One evidence unit per ASN: best member carries it, siblings add log2 weight,
  # crowded ASNs (pool infrastructure) get a sqrt-tapered discount.
  def build_groups(evidence_items, co_users_per_asn)
    groups = evidence_items.group_by { |e| e[:asn_group] }.map do |group, items|
      best = items.first # arrive sorted by contribution desc
      collapsed = best[:contribution] * (1 + (ASN_SIBLING_WEIGHT * Math.log2(items.size)))
      crowd = asn_crowd_factor(co_users_per_asn[group] || 2)
      { group: group, size: items.size, best: best, crowd_factor: crowd, contribution: collapsed * crowd }
    end
    groups.sort_by { |g| -g[:contribution] }
  end

  def asn_crowd_factor(count)
    count <= ASN_CROWD_FREE ? 1.0 : Math.sqrt(ASN_CROWD_FREE.to_f / count)
  end

  # A fresh account taking over a shared IP: the later usage window starts within
  # HANDOFF_DAYS of the earlier one ending, AND that later account was itself
  # created within HANDOFF_DAYS of the handoff. Symmetric in the two accounts.
  def handoff?(target_user, cand_user, shared_exact)
    shared_exact.any? do |e|
      a = e[:mine]
      b = e[:theirs]
      early, late, late_user = a[:first] <= b[:first] ? [a, b, cand_user] : [b, a, target_user]
      gap_days = (late[:first] - early[:last]) / 1.day
      next false unless gap_days.between?(-1.0, HANDOFF_DAYS)
      ((late_user.created_at - early[:last]).abs / 1.day) <= HANDOFF_DAYS
    end
  end

  # --- ASN helpers ----------------------------------------------------------

  # { value_key => { asn:, name:, country: } | nil }. Empty (ASN grouping off)
  # when asn_ranges is missing/empty; unresolved values fall back to their own
  # subnet so they never merge across providers.
  def resolve_asns(ip_keys, subnet_keys)
    return {} unless AsnRange.table_exists? && AsnRange.exists?
    subnet_bases = subnet_keys.index_with { |k| IPAddr.new(k).to_s }
    raw = AsnRange.lookup(ip_keys + subnet_bases.values)
    map = {}
    ip_keys.each { |ip| map[ip] = raw[IPAddr.new(ip).to_s] }
    subnet_bases.each { |cidr, base| map[cidr] = raw[base] }
    map
  end

  def asn_group_for(value, asn_map)
    info = asn_map[value]
    return "AS#{info[:asn]}" if info
    value.include?("/") ? value : subnet_cidr_for_ip(value)
  end

  # --- small helpers --------------------------------------------------------

  # Canonical string key for a value read back from the DB (IPAddr or string).
  # Subnets keep their prefix so /24 and /64 stay distinct from host addresses.
  def canonical(column, value)
    column == :subnet ? cidr(value) : IPAddr.new(value.to_s).to_s
  end

  def cidr(ipaddr)
    ip = ipaddr.is_a?(IPAddr) ? ipaddr : IPAddr.new(ipaddr.to_s)
    "#{ip}/#{ip.prefix}"
  end

  def subnet_cidr_for_ip(ip_string)
    addr = IPAddr.new(ip_string)
    mask = addr.ipv4? ? 24 : 64
    "#{addr.mask(mask)}/#{mask}"
  end

  def subnet_weight(subnet_cidr)
    IPAddr.new(subnet_cidr).ipv4? ? weight_subnet_v4 : weight_subnet_v6
  end

  def deleted?(user)
    user&.name&.match?(/\Auser_#{user.id}~*\z/)
  end

  # --- config accessors -----------------------------------------------------

  def max_users_per_ip     = Danbooru.config.alt_finder_max_users_per_ip
  def max_users_per_subnet = Danbooru.config.alt_finder_max_users_per_subnet
  def weight_exact         = Danbooru.config.alt_finder_weight_exact
  def weight_subnet_v6     = Danbooru.config.alt_finder_weight_subnet_v6
  def weight_subnet_v4     = Danbooru.config.alt_finder_weight_subnet_v4
  def proximity_half_life  = Danbooru.config.alt_finder_proximity_half_life_days
  def saturation           = Danbooru.config.alt_finder_score_saturation
  def target_ip_cap        = Danbooru.config.alt_finder_target_ip_cap
  def candidate_cap        = Danbooru.config.alt_finder_candidate_cap
end
