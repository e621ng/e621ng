# frozen_string_literal: true

require "rails_helper"

# Real pushes to the test Redis through the client middleware, proving the lock
# keys on full args: an approve-finalize and an undo-finalize for the same
# implication differ only by the undo flag and must both survive, while two
# identical approve-finalizes dedup. Private random queue + digest cleanup keep
# it safe on the shared Redis DB 0.
RSpec.describe TagImplicationFinalizeJob do
  around do |example|
    Sidekiq::Testing.disable! do
      SidekiqUniqueJobs.config.enabled = true
      example.run
    ensure
      SidekiqUniqueJobs.config.enabled = false
    end
  end

  it "dedups identical finalizes but keeps approve and undo distinct" do
    queue_name = "finlockspec_#{SecureRandom.hex(6)}"
    id = SecureRandom.random_number(2**31)
    name = "finlockspec_#{SecureRandom.hex(8)}"

    approve1 = described_class.set(queue: queue_name).perform_async(id, name)
    approve2 = described_class.set(queue: queue_name).perform_async(id, name)
    undo = described_class.set(queue: queue_name).perform_async(id, name, true)

    expect(approve1).to be_present
    expect(approve2).to be_nil # identical approve-finalize deduped
    expect(undo).to be_present # differs by the undo flag, must survive

    queue = Sidekiq::Queue.new(queue_name)
    expect(queue.map(&:args)).to contain_exactly([id, name], [id, name, true])
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
