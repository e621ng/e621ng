# frozen_string_literal: true

class TagBatchJob < ApplicationJob
  queue_as :tags

  def perform(*args)
    antecedent = args[0]
    consequent = args[1]
    updater_id = args[2]
    updater_ip_addr = args[3]

    from, *from_remaining = TagQuery.scan(antecedent.downcase)
    to, *to_remaining = TagQuery.scan(consequent.downcase)
    raise JobError, "#{antecedent} or #{consequent} has unexpected format" if from_remaining.any? || to_remaining.any?

    updater = User.find(updater_id)

    CurrentUser.scoped(updater, updater_ip_addr) do
      create_undo_information(antecedent, consequent)
      migrate_posts(from, to)
      migrate_blacklists(from, to)
      ModAction.log(:mass_update, { antecedent: antecedent, consequent: consequent })
    end
  end

  def migrate_posts(from, to)
    Post.sql_raw_tag_match(from).find_each do |post|
      post.with_lock do
        post.do_not_version_changes = true
        post.remove_tag(from)
        post.add_tag(to)
        post.save
      end
    end
  end

  def migrate_blacklists(from, to)
    User.without_timeout do
      User.where_ilike(:blacklisted_tags, "*#{from}*").find_each(batch_size: 50) do |user|
        fixed_blacklist = TagAlias.to_aliased_query(user.blacklisted_tags, overrides: { from => to })
        user.update_column(:blacklisted_tags, fixed_blacklist)
      end
    end
  end

  def create_undo_information(antecedent_tag, consequent_tag)
    Post.transaction do
      Post.without_timeout do
        post_info = Hash.new
        Post.sql_raw_tag_match(antecedent_tag).find_in_batches do |posts|
          posts.each do |p|
            post_info[p.id] = p.tag_string
          end
        end
        TagRelUndo.create!(tag_rel: "#{antecedent_tag}_#{consequent_tag}", undo_data: post_info)
      end
    end
  end

  def self.process_undo!(tag)
    split = tag.split("_")
    antecedent = split[0]
    consequent = split[1]
    Post.without_timeout do
      TagRelUndo.where(tag_rel: tag, applied: false).find_each do |tag_rel_undo|
        Post.where(id: tag_rel_undo.undo_data.keys).find_each do |post|
          post.do_not_version_changes = true
          if TagQuery.scan(tag_rel_undo.undo_data[post.id]).include?(consequent)
            post.tag_string_diff = antecedent
          else
            post.tag_string_diff = "#{antecedent} -#{consequent}"
          end
          post.save
        end
        tag_rel_undo.update(applied: true)
      end
    end
  end
end
