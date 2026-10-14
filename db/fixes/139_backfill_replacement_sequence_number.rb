# frozen_string_literal: true

# Backfills sequence_number on post_replacements2.
# Establishes the invariant 0 = the original backup, 1..N = replacements in creation (id) order
# within each post.
#
# Two set-based UPDATEs, not per-row Ruby. The original is numbered by status, so a legacy
# "misordered" backup (higher id than the replacement it backed up) still sorts first.
# 0 is reserved for the original, so posts without one simply start at 1.
# Idempotent: the assignment is deterministic, so re-running yields the same result.
#
# Run only while replacement creation is frozen so no new NULL rows appear mid-run.
module Fixes
  class BackfillReplacementSequenceNumber
    def self.run
      conn = PostReplacement.connection

      PostReplacement.without_timeout do
        originals = conn.execute(<<~SQL.squish).cmd_tuples
          UPDATE post_replacements2 SET sequence_number = 0 WHERE status = 'original'
        SQL

        replacements = conn.execute(<<~SQL.squish).cmd_tuples
          UPDATE post_replacements2 pr SET sequence_number = sub.rn
          FROM (
            SELECT id, row_number() OVER (PARTITION BY post_id ORDER BY id) AS rn
            FROM post_replacements2 WHERE status <> 'original'
          ) sub
          WHERE pr.id = sub.id
        SQL

        puts "Backfilled sequence_number: #{originals} originals (0), #{replacements} replacements (1..N)"
      end
    end
  end
end

Fixes::BackfillReplacementSequenceNumber.run
