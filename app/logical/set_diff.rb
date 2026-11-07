# frozen_string_literal: true

class SetDiff
  # Levenshtein is O(n*m) in pure Ruby; cap the work so a single diff of
  # user-controlled strings can't pin a web worker (E6SEC-801).
  MAX_PAIR_CELLS = 250 * 250
  MAX_TOTAL_CELLS = 2_000_000

  attr_reader :additions, :removals, :added, :removed, :obsolete_added, :obsolete_removed, :changed, :unchanged

  def initialize(new, old, latest)
    new, old, latest = new.to_a, old.to_a, latest.to_a
    @cells_used = 0

    @additions = new - old
    @removals = old - new
    @unchanged = new & old
    @obsolete_added = additions - latest
    @obsolete_removed = removals & latest
    @added, @removed, @changed = changes(additions, removals)
  end

  def changes(added, removed)
    changed = []

    removed.each do |removal|
      if addition = find_similar(removal, added)
        changed << [removal, addition]
        added -= [addition]
        removed -= [removal]
      end
    end

    [added, removed, changed]
  end

  def find_similar(string, candidates, max_dissimilarity: 0.70)
    max_distance = string.size * max_dissimilarity

    scored = candidates.filter_map do |candidate|
      # length difference is a lower bound on edit distance
      next if (string.size - candidate.size).abs > max_distance

      cells = string.size * candidate.size
      next if cells > MAX_PAIR_CELLS || @cells_used + cells > MAX_TOTAL_CELLS

      @cells_used += cells
      distance = DidYouMean::Levenshtein.distance(string, candidate)
      [distance, candidate] if distance <= max_distance
    end

    scored.min_by(&:first)&.last
  end
end
