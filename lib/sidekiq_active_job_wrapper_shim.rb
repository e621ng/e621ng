# frozen_string_literal: true

# TEMPORARY deploy shim: payloads enqueued before the ActiveJob -> native Sidekiq
# migration have class Sidekiq::ActiveJob::Wrapper and would fail to execute now
# that the job classes are no longer ActiveJobs. Run them natively instead.
# Remove once pre-migration payloads have drained from the queues, the scheduled
# set (24h horizon), and the retry set (~21 day horizon).
require "active_job/queue_adapters/sidekiq_adapter"

module SidekiqActiveJobWrapperShim
  def perform(job_data)
    klass = job_data["job_class"].constantize
    # e.g. ActionMailer::MailDeliveryJob is still a real ActiveJob.
    return super if klass <= ActiveJob::Base

    Sidekiq.logger.info do
      "wrapper-shim: legacy payload for #{job_data['job_class']} jid=#{jid} enqueued_at=#{job_data['enqueued_at']}"
    end
    klass.new.perform(*ActiveJob::Arguments.deserialize(job_data["arguments"]))
  end
end

Sidekiq::ActiveJob::Wrapper.prepend(SidekiqActiveJobWrapperShim)
