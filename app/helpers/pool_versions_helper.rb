# frozen_string_literal: true

module PoolVersionsHelper
  def pool_version_posts_diff(pool_version)
    changes = []

    pool_version.added_post_ids.each do |post_id|
      changes << tag.ins(link_to(post_id, post_path(post_id)))
    end

    pool_version.removed_post_ids.each do |post_id|
      changes << tag.del(link_to(post_id, post_path(post_id)))
    end

    safe_join(changes, " ")
  end
end
