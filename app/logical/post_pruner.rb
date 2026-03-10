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
    dmail = Danbooru.config.post_pruned_dmail_template.presence

    CurrentUser.as_system do
      Post.where("is_deleted = ? and is_pending = ? and created_at < ?", false, true, window.ago).find_each do |post|
        if dmail.is_a?(Hash) && dmail[:body].presence
          Dmail.create_automated({
            to_id: post.uploader.id,
            title: dmail[:title].presence || "Post ##{post.id} has been deleted",
            body: dmail[:body]
              .gsub("%POST_ID%", post.id.to_s)
              .gsub("%UPLOADER_ID%", post.uploader_id.to_s),
          })
        end
        post.delete!("Unapproved in #{window.inspect}")
      rescue PostFlag::Error
        # swallow
      end
    end
  end
end
