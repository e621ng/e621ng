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

  def self.create_undo_information(antecedent_tag, consequent_tag)
    undo_info = Hash.new
    undo_info["antecedent"] = antecedent_tag
    undo_info["consequent"] = consequent_tag
    undo_info["posts"] = Hash.new

    Post.transaction do
      Post.without_timeout do
        Post.sql_raw_tag_match(antecedent_tag).find_in_batches do |posts|
          posts.each do |p|
            undo_info["posts"][p.id] = p.tag_string
          end
        end
      end
    end
    
    return undo_info
  end

  def self.process_undo!(undo_info)
    antecedent = undo_info["antecedent"]
    consequent = undo_info["consequent"]
    posts = undo_info["posts"]
    Post.without_timeout do
      Post.where(id: posts.keys).find_each do |post|
        post.do_not_version_changes = true
        if TagQuery.scan(posts[post.id]).include?(consequent)
          post.tag_string_diff = antecedent
        else
          post.tag_string_diff = "#{antecedent} -#{consequent}"
        end
        post.save
      end
    end
  end
end
