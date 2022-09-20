class PostPruner
  DELETION_WINDOW = 30

  def prune!
    Post.without_timeout do
      prune_pending!
    end
  end

  protected

  def prune_pending!
    CurrentUser.scoped(User.system, "127.0.0.1") do
      Post.where("is_deleted = ? and is_pending = ? and created_at < ?", false, true, DELETION_WINDOW.days.ago).each do |post|
        post.delete!("Unapproved in #{DELETION_WINDOW} days")
      rescue PostFlag::Error
        # swallow
      end
    end
  end
end
