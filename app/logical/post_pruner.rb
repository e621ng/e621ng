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
    dmail = Danbooru.config.post_pruned_dmail_template

    CurrentUser.as_system do
      Post.where("is_deleted = ? and is_pending = ? and created_at < ?", false, true, window.ago).find_each do |post|
        post.delete!("Unapproved in #{window.inspect}")
        if dmail.is_a?(Hash) && dmail[:body].present?
          Dmail.create_automated({
            to_id: post.uploader.id,
            title: post.substitute_deletion_dmail_template(dmail[:title]) || "Post ##{post.id} has been deleted",
            body: post.substitute_deletion_dmail_template(dmail[:body]),
          })
        end
      rescue PostFlag::Error
        # swallow
      end
    end
  end
end
