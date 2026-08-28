# frozen_string_literal: true

# Parses the SIDEKIQ_CAPSULES env var into Sidekiq capsule definitions.
# Capsules get their own thread pool, giving per-queue concurrency caps
# within a single process (e.g. "at most 2 concurrent video transcodes").
#
# Format: semicolon-separated "<name> <concurrency> <queue>[:<weight>],..."
#   SIDEKIQ_CAPSULES="media 2 video:1,thumb:1;iqdb 1 iqdb"
module SidekiqCapsules
  def self.parse(raw)
    capsules = raw.to_s.split(";")
                  .map(&:strip)
                  .reject(&:empty?)
                  .map { |spec| parse_capsule(spec) }

    duplicates = capsules.pluck(:name).tally.select { |_, count| count > 1 }.keys
    raise ArgumentError, "SIDEKIQ_CAPSULES: duplicate capsule name(s): #{duplicates.join(', ')}" if duplicates.any?

    capsules
  end

  def self.parse_capsule(spec)
    name, concurrency, queues = spec.split(/\s+/, 3)
    raise ArgumentError, "SIDEKIQ_CAPSULES: expected \"<name> <concurrency> <queues>\", got #{spec.inspect}" if queues.nil? || queues.strip.empty?
    raise ArgumentError, "SIDEKIQ_CAPSULES: \"default\" is reserved; configure it through SIDEKIQ_QUEUES" if name == "default"

    {
      name: name,
      concurrency: parse_concurrency(name, concurrency),
      queues: parse_queues(name, queues),
    }
  end

  def self.parse_concurrency(name, value)
    concurrency = Integer(value, exception: false)
    raise ArgumentError, "SIDEKIQ_CAPSULES: capsule #{name}: concurrency must be a positive integer, got #{value.inspect}" if concurrency.nil? || concurrency < 1

    concurrency
  end

  def self.parse_queues(name, value)
    value.split(",").map(&:strip).reject(&:empty?).map do |entry|
      queue, weight = entry.split(":", 2)
      weight ||= "1"
      raise ArgumentError, "SIDEKIQ_CAPSULES: capsule #{name}: queue name cannot be empty" if queue.nil? || queue.strip.empty?
      raise ArgumentError, "SIDEKIQ_CAPSULES: capsule #{name}: invalid queue entry #{entry.inspect}" unless weight.match?(/\A[1-9]\d*\z/)

      [queue, Integer(weight)]
    end
  end
end
