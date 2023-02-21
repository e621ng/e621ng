class TagBatchJob < ApplicationJob
  queue_as :tags

  def perform(*args)
    antecedent = args[0]
    consequent = args[1]
    updater_id = args[2]
    updater_ip_addr = args[3]

    scanned_antecedent = Tag.scan_tags(antecedent.downcase)
    scanned_consequent = Tag.scan_tags(consequent.downcase)
    raise JobError, "#{antecedent} or #{consequent} has unexpected format" if scanned_antecedent.count != 1 || scanned_consequent.count != 1

    normalized_antecedent = TagAlias.to_aliased(scanned_antecedent).first
    normalized_consequent = TagAlias.to_aliased(scanned_consequent).first
    updater = User.find(updater_id)

    CurrentUser.without_safe_mode do
      CurrentUser.scoped(updater, updater_ip_addr) do
        migrate_posts(normalized_antecedent, normalized_consequent)
        migrate_blacklists(normalized_antecedent, normalized_consequent)
        ModAction.log(:mass_update, { antecedent: antecedent, consequent: consequent })
      end
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

  # this can't handle negated tags or other special cases
  def migrate_blacklists(normalized_antecedent, normalized_consequent)
    User.where("blacklisted_tags like ?", "%#{normalized_antecedent.to_escaped_for_sql_like}%").find_each do |user|
      changed = false

      repl = user.blacklisted_tags.split(/\r\n|\r|\n/).map do |line|
        list = Tag.scan_tags(line)
        if list.include?(normalized_antecedent)
          changed = true
          (list - [normalized_antecedent] + [normalized_consequent]).join(" ")
        else
          line
        end
      end

      if changed
        user.update(blacklisted_tags: repl.join("\n"))
      end
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
    end
  end
end
