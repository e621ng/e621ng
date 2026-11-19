# frozen_string_literal: true

module Populate
  module Media
    # Which media tier each imported post currently has on disk (seed.media).
    module Ledger
      TABLE = "#{Exports::SCHEMA}.media".freeze

      module_function

      def ensure!
        connection.execute("CREATE SCHEMA IF NOT EXISTS #{Exports::SCHEMA}")
        connection.execute("CREATE TABLE IF NOT EXISTS #{TABLE} (post_id bigint PRIMARY KEY, tier text NOT NULL, created_at timestamp NOT NULL)")
      end

      # Post ids from the list that already have media, optionally only of the given tier.
      def recorded(post_ids, tier: nil)
        return [] if post_ids.empty?
        ensure!
        tier_clause = tier ? " AND tier = #{connection.quote(tier)}" : ""
        connection.select_values("SELECT post_id FROM #{TABLE} WHERE post_id = ANY(#{Selection.array_literal(post_ids)})#{tier_clause}").map(&:to_i)
      end

      def record(post_ids, tier)
        return if post_ids.empty?
        ensure!
        now = connection.quote(Time.current.utc)
        values = post_ids.map { |id| "(#{id.to_i}, #{connection.quote(tier)}, #{now})" }.join(",")
        connection.execute("INSERT INTO #{TABLE} (post_id, tier, created_at) VALUES #{values} ON CONFLICT (post_id) DO UPDATE SET tier = EXCLUDED.tier, created_at = EXCLUDED.created_at")
      end

      def connection
        ActiveRecord::Base.connection
      end
    end

    # Runs the block over the items on a small thread pool; returns [[item, error_or_nil], ...].
    module WorkerPool
      module_function

      def each(items, threads)
        queue = Queue.new
        items.each { |item| queue << item }
        queue.close
        results = Queue.new

        workers = Array.new([threads, 1].max) do
          Thread.new do
            Rails.application.executor.wrap do
              while (item = queue.pop)
                begin
                  yield(*item)
                  results << [item, nil]
                rescue StandardError => e
                  results << [item, "#{e.class}: #{e.message}"]
                end
              end
            end
          end
        end
        workers.each(&:join)

        out = []
        out << results.pop until results.empty?
        out
      end
    end
  end
end
