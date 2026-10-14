# frozen_string_literal: true

# TEMPORARY deploy shim: payloads enqueued before the ActiveJob -> native Sidekiq
# migration have class Sidekiq::ActiveJob::Wrapper and would fail to execute now
# that the job classes are no longer ActiveJobs. Run them natively instead.
# Remove once pre-migration payloads have drained from the queues, the scheduled
# set (24h horizon), and the retry set (~21 day horizon).
require "active_job/queue_adapters/sidekiq_adapter"

module SidekiqActiveJobWrapperShim
  # These three jobs changed from keyword to positional parameters in the
  # migration. Their legacy payloads deserialize the kwargs into a trailing
  # symbol-keyed hash, which would otherwise reach perform as the wrong arity
  # (AutomodUserCheckJob) or as a Hash where a boolean is expected. Translate
  # each back into the new positional order; the option defaults cover legacy
  # payloads that were enqueued without the keyword.
  KWARG_REMAPS = {
    "AutomodUserCheckJob" => ->(user_id, opts = {}) { [user_id, opts[:check_username], opts[:check_profile]] },
    "AvatarCleanupJob" => ->(user_id, opts = {}) { [user_id, opts.fetch(:force, false)] },
    "TagImplicationFinalizeJob" => ->(id, reindex_tag_name, opts = {}) { [id, reindex_tag_name, opts.fetch(:undo, false)] },
  }.freeze

  def perform(job_data)
    klass = job_data["job_class"].constantize
    # e.g. ActionMailer::MailDeliveryJob is still a real ActiveJob.
    return super if klass <= ActiveJob::Base

    Sidekiq.logger.info do
      "wrapper-shim: legacy payload for #{job_data['job_class']} jid=#{jid} enqueued_at=#{job_data['enqueued_at']}"
    end

    args = ActiveJob::Arguments.deserialize(job_data["arguments"])
    remap = KWARG_REMAPS[job_data["job_class"]]
    args = remap.call(*args) if remap
    klass.new.perform(*args)
  end
end

Sidekiq::ActiveJob::Wrapper.prepend(SidekiqActiveJobWrapperShim)
