# frozen_string_literal: true

module Fixes
  class ZeroDeprecatedUserBitflags
    def self.run
      mask = User.deprecated_bit_prefs_mask
      processed = 0
      User.without_timeout do
        User.where("bit_prefs & ? != 0", mask).in_batches(of: 10_000) do |batch|
          processed += batch.size
          batch.update_all(["bit_prefs = bit_prefs & ~?::bigint", mask])
          sleep(0.1) # bound replica lag / let autovacuum breathe; ~140 batches

          puts "Processed #{processed} users"
        end
      end
    end
  end
end

Fixes::ZeroDeprecatedUserBitflags.run
