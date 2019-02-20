class PostPruner
  def prune!
    Post.without_timeout do
      prune_pending!
    end
  end

protected

  def prune_pending!
    CurrentUser.scoped(User.system, "127.0.0.1") do
      Post.where("is_deleted = ? and is_pending = ? and created_at < ?", false, true, 30.days.ago).each do |post|
        begin
          post.delete!("Unapproved in 30 days")
        rescue PostFlag::Error
          # swallow
        end
      end
    end
  end
end
