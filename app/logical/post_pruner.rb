# frozen_string_literal: true

class PostPruner
  def prune!
    Post.without_timeout do
      prune_pending!
    end
  end

  protected

  def prune_pending!
    CurrentUser.as_system do
      Post.where("is_deleted = ? and is_pending = ? and created_at < ?", false, true, Danbooru.config.auto_deletion_window.days.ago).find_each do |post|
        post.delete!("Unapproved in #{Danbooru.config.auto_deletion_window} days")
      rescue PostFlag::Error
        # swallow
      end
    end
  end
end
