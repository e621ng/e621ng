# frozen_string_literal: true

class TagBatchJob < ApplicationJob
  queue_as :tags

  def perform(*args)
    antecedent = args[0]
    consequent = args[1]
    updater_id = args[2]
    updater_ip_addr = args[3]

    scanned_antecedent = TagQuery.scan(antecedent.downcase)
    scanned_consequent = TagQuery.scan(consequent.downcase)
    raise JobError, "#{antecedent} or #{consequent} has unexpected format" if scanned_antecedent.count != 1 || scanned_consequent.count != 1

    normalized_antecedent = TagAlias.to_aliased(scanned_antecedent).first
    normalized_consequent = TagAlias.to_aliased(scanned_consequent).first
    updater = User.find(updater_id)

    CurrentUser.scoped(updater, updater_ip_addr) do
      migrate_posts(normalized_antecedent, normalized_consequent)
      migrate_blacklists(normalized_antecedent, normalized_consequent)
      ModAction.log(:mass_update, { antecedent: antecedent, consequent: consequent })
    end
  end

  def migrate_posts(normalized_antecedent, normalized_consequent)
    Post.sql_raw_tag_match(normalized_antecedent).find_each do |post|
      post.with_lock do
        post.do_not_version_changes = true
        post.tag_string_diff = "-#{normalized_antecedent} #{normalized_consequent}"
        post.save
      end
    end
  end

  def migrate_blacklists(normalized_antecedent, normalized_consequent)
    User.without_timeout do
      User.where_ilike(:blacklisted_tags, "*#{normalized_antecedent}*").find_each(batch_size: 50) do |user|
        fixed_blacklist = TagAlias.to_aliased_query(user.blacklisted_tags, overrides: { normalized_antecedent => normalized_consequent })
        user.update_column(:blacklisted_tags, fixed_blacklist)
      end
    end
  end
end
