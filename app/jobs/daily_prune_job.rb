# frozen_string_literal: true

# Daily cleanup of expired or inconsistent database records. Every task is
# idempotent, so default retries are safe. Each task is isolated so that one
# failure doesn't skip the rest.
class DailyPruneJob < ApplicationJob
  sidekiq_options queue: "low_prio", lock: :until_executed, lock_ttl: 12.hours.to_i

  def perform
    ApplicationRecord.without_timeout do
      run_task { Upload.where("created_at < ?", Danbooru.config.upload_deletion_window.ago).delete_all }
      run_task { TagAlias.update_cached_post_counts_for_all }
      run_task { Tag.clean_up_negative_post_counts! }
      run_task { Ban.prune! }
      run_task { UserPasswordResetNonce.prune! }
      run_task { ExceptionLog.prune! unless Setting.disable_exception_prune? }
      run_task { Post.cleanup_stuck_favorite_transfer_flags! }
    end
  end

  private

  def run_task
    yield
  rescue StandardError => e
    DanbooruLogger.log(e)
  end
end
