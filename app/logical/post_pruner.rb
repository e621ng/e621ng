class PostPruner
  DELETION_WINDOW = 30

  def prune!
    Post.without_timeout do
      prune_pending!
    end
  end

  protected

  def prune_pending!
    CurrentUser.as_system do
      Post.where("is_deleted = ? and is_pending = ? and created_at < ?", false, true, DELETION_WINDOW.days.ago).find_each do |post|
        post.delete!("Unapproved in #{DELETION_WINDOW} days")
      rescue PostFlag::Error
        # swallow
      end
    end
  end
end
