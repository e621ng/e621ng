# frozen_string_literal: true

class TagNukeJob < ApplicationJob
  queue_as :tags
  sidekiq_options lock: :until_executed, lock_args_method: :lock_args

  def self.lock_args(args)
    [args[0]]
  end

  def perform(*args)
    tag_name = args[0]
    tag = Tag.find_by_normalized_name(tag_name)
    updater_id = args[1]
    updater_ip_addr = args[2]
    return if tag.nil?

    updater = User.find(updater_id)

    CurrentUser.scoped(updater, updater_ip_addr) do
      migrate_posts(tag.name)
      ModAction.log(:nuke_tag, { tag_name: tag_name })
    end
  end

  def migrate_posts(tag_name)
    Post.sql_raw_tag_match(tag_name).find_each do |post|
      post.with_lock do
        post.do_not_version_changes = true
        post.remove_tag(tag_name)
        post.save
      end
    end
  end

  def self.create_undo_information(tag)
    undo_info = {}
    undo_info["tag"] = tag
    undo_info["post_ids"] = []

    Post.transaction do
      Post.without_timeout do
        Post.sql_raw_tag_match(tag).find_each do |post|
          undo_info["post_ids"] << post.id
        end
      end
    end

    undo_info
  end

  def self.process_undo!(undo_info)
    tag = undo_info["tag"]
    Post.where(id: undo_info["post_ids"]).find_each do |post|
      post.do_not_version_changes = true
      post.add_tag(tag)
      post.save
    end
  end
end
