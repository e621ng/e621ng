# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("lib/sidekiq_active_job_wrapper_shim")

RSpec.describe SidekiqActiveJobWrapperShim do
  def wrapper_job_data(job_class, arguments)
    {
      "job_class" => job_class,
      "job_id" => SecureRandom.uuid,
      "provider_job_id" => nil,
      "queue_name" => "default",
      "priority" => nil,
      "arguments" => arguments,
      "executions" => 0,
      "exception_executions" => {},
      "locale" => "en",
      "timezone" => "UTC",
      "enqueued_at" => Time.current.utc.iso8601(9),
    }
  end

  it "executes legacy payloads for migrated jobs natively" do
    instance = instance_double(IqdbRemoveJob)
    allow(IqdbRemoveJob).to receive(:new).and_return(instance)
    allow(instance).to receive(:perform)

    Sidekiq::ActiveJob::Wrapper.new.perform(wrapper_job_data("IqdbRemoveJob", [123]))

    expect(instance).to have_received(:perform).with(123)
  end

  it "revives ActiveJob-serialized symbol arguments" do
    instance = instance_double(PostSetCleanupJob)
    allow(PostSetCleanupJob).to receive(:new).and_return(instance)
    allow(instance).to receive(:perform)

    symbol_arg = { "_aj_serialized" => "ActiveJob::Serializers::SymbolSerializer", "value" => "pool" }
    Sidekiq::ActiveJob::Wrapper.new.perform(wrapper_job_data("PostSetCleanupJob", [symbol_arg, 42]))

    expect(instance).to have_received(:perform).with(:pool, 42)
  end

  it "remaps a legacy keyword payload for a job that is now positional" do
    instance = instance_double(AutomodUserCheckJob)
    allow(AutomodUserCheckJob).to receive(:new).and_return(instance)
    allow(instance).to receive(:perform)

    # Serialized shape of perform_later(5, check_username: true, check_profile: false).
    kwargs = { "check_username" => true, "check_profile" => false, "_aj_ruby2_keywords" => %w[check_username check_profile] }
    Sidekiq::ActiveJob::Wrapper.new.perform(wrapper_job_data("AutomodUserCheckJob", [5, kwargs]))

    expect(instance).to have_received(:perform).with(5, true, false)
  end

  it "defaults the option when a legacy payload omitted the keyword" do
    instance = instance_double(TagImplicationFinalizeJob)
    allow(TagImplicationFinalizeJob).to receive(:new).and_return(instance)
    allow(instance).to receive(:perform)

    # perform_later(7, "some_tag") — the undo: keyword was never supplied.
    Sidekiq::ActiveJob::Wrapper.new.perform(wrapper_job_data("TagImplicationFinalizeJob", [7, "some_tag"]))

    expect(instance).to have_received(:perform).with(7, "some_tag", false)
  end

  it "delegates payloads for classes that are still ActiveJobs" do
    # Deliberately a raw ActiveJob: ApplicationJob is a native Sidekiq job now.
    stub_const("ShimSpecActiveJob", Class.new(ActiveJob::Base)) # rubocop:disable Rails/ApplicationJob
    allow(ActiveJob::Base).to receive(:execute)

    Sidekiq::ActiveJob::Wrapper.new.perform(wrapper_job_data("ShimSpecActiveJob", []))

    expect(ActiveJob::Base).to have_received(:execute).with(hash_including("job_class" => "ShimSpecActiveJob"))
  end
end
