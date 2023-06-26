module Maintenance
  module_function

  def daily
    return if Danbooru.config.readonly_mode?

    ignoring_exceptions { PostPruner.new.prune! }
    ignoring_exceptions { Upload.where('created_at < ?', 1.week.ago).delete_all }
    ignoring_exceptions { ForumSubscription.process_all! }
    ignoring_exceptions { TagAlias.update_cached_post_counts_for_all }
    ignoring_exceptions { Tag.clean_up_negative_post_counts! }
    ignoring_exceptions { Ban.prune! }
    ignoring_exceptions { UserPasswordResetNonce.prune! }
    ignoring_exceptions { StatsUpdater.run! }
    ignoring_exceptions { JanitorReportGenerator.run! }
  end

  def ignoring_exceptions(&block)
    ActiveRecord::Base.connection.execute("set statement_timeout = 0")
    yield
  rescue StandardError => exception
    DanbooruLogger.log(exception)
  end
end
