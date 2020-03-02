module Maintenance
  module_function

  def daily
    ignoring_exceptions { PostPruner.new.prune! }
    ignoring_exceptions { Upload.where('created_at < ?', 1.week.ago).delete_all }
    ignoring_exceptions { ApiCacheGenerator.new.generate_tag_cache }
    ignoring_exceptions { PostDisapproval.prune! }
    ignoring_exceptions { ForumSubscription.process_all! }
    ignoring_exceptions { TagAlias.update_cached_post_counts_for_all }
    #ignoring_exceptions { PostDisapproval.dmail_messages! }
    ignoring_exceptions { Tag.clean_up_negative_post_counts! }
    #ignoring_exceptions { TagChangeRequestPruner.warn_all }
    #ignoring_exceptions { TagChangeRequestPruner.reject_all }
    ignoring_exceptions { Ban.prune! }
    ignoring_exceptions { UserPasswordResetNonce.prune! }
  end

  def weekly
    #ignoring_exceptions { ApproverPruner.prune! }
    #ignoring_exceptions { TagRelationshipRetirementService.find_and_retire! }
  end

  def ignoring_exceptions(&block)
    ActiveRecord::Base.connection.execute("set statement_timeout = 0")
    yield
  rescue StandardError => exception
    DanbooruLogger.log(exception)
  end
end
