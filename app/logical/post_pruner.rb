# frozen_string_literal: true

class PostPruner
  def prune!
    Post.without_timeout do
      prune_pending!
    end
  end

  protected

  def prune_pending!
    window = Danbooru.config.unapproved_post_deletion_window

    CurrentUser.as_system do
      Post.where("is_deleted = ? and is_pending = ? and created_at < ?", false, true, window.ago).find_each do |post|
        post.delete!("Unapproved in #{window.inspect}")
      rescue PostFlag::Error
        # swallow
      end
    end
  end
end
