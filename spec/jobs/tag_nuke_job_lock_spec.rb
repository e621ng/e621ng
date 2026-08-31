# frozen_string_literal: true

require "rails_helper"

# End-to-end proof that sidekiq-unique-jobs dedups native payloads: real pushes
# to the test Redis through the real client middleware. The Redis instance is
# shared with parallel workers and (in dev setups) a live Sidekiq worker, so the
# pushes go to a private random queue nobody consumes, and the cleanup only
# touches that queue and this example's own digests.
RSpec.describe TagNukeJob do
  around do |example|
    Sidekiq::Testing.disable! do
      SidekiqUniqueJobs.config.enabled = true
      example.run
    ensure
      SidekiqUniqueJobs.config.enabled = false
    end
  end

  it "drops a duplicate enqueue for the same tag but accepts a different tag" do
    queue_name = "lockspec_#{SecureRandom.hex(6)}"
    tag_a = "lockspec_#{SecureRandom.hex(8)}"
    tag_b = "lockspec_#{SecureRandom.hex(8)}"

    jid1 = described_class.set(queue: queue_name).perform_async(tag_a, 1, "127.0.0.1")
    jid2 = described_class.set(queue: queue_name).perform_async(tag_a, 2, "127.0.0.1") # same lock_args -> [tag_a]
    jid3 = described_class.set(queue: queue_name).perform_async(tag_b, 1, "127.0.0.1")

    expect(jid1).to be_present
    expect(jid2).to be_nil
    expect(jid3).to be_present

    queue = Sidekiq::Queue.new(queue_name)
    expect(queue.map { |j| j.args[0] }).to contain_exactly(tag_a, tag_b)
  ensure
    queue = Sidekiq::Queue.new(queue_name)
    queue.each do |j|
      digest = j.item["lock_digest"]
      next unless digest

      SidekiqUniqueJobs::Digests.new.delete_by_digest(digest)
      SidekiqUniqueJobs::ExpiringDigests.new.delete_by_digest(digest)
    end
    queue.clear
  end
end
