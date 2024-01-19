#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

def update(model, text)
  model.where.not(forum_post_id: nil).find_each do |record|
    if record.forum_post.present? && record.forum_post.body.start_with?("[#{text}:#{record.id}]")
      record.forum_post.update_column(:body, record.forum_post.body.gsub(/\[#{text}:#{record.id}\](?:\r?\n)*/, ""))
    end
  end
end

update(TagAlias, "ta")
update(TagImplication, "ti")
update(BulkUpdateRequest, "bur")
