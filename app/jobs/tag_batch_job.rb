class TagBatchJob < ApplicationJob
  queue_as :tags

  def perform(*args)
    @antecedent = args[0]
    @consequent = args[1]
    @updater_id = args[2]
    @updater_ip_addr = args[3]
    raise JobError.new("antecedent is missing") if @antecedent.blank?

    normalized_antecedent = TagAlias.to_aliased(::Tag.scan_tags(@antecedent.mb_chars.downcase))
    normalized_consequent = TagAlias.to_aliased(::Tag.scan_tags(@consequent.mb_chars.downcase))
    updater = User.find(@updater_id)

    CurrentUser.without_safe_mode do
      CurrentUser.scoped(updater, @updater_ip_addr) do
        migrate_posts(normalized_antecedent, normalized_consequent)
        migrate_blacklists(normalized_antecedent, normalized_consequent)
      end
    end

    ModAction.log(:mass_update, {antecedent: @antecedent, consequent: @consequent})
  end

  def estimate_update_count
    ::Post.tag_match(@antecedent).count
  end

  def migrate_posts(normalized_antecedent, normalized_consequent)
    ::PostQueryBuilder.new(normalized_antecedent.join(" ")).build.reorder('').find_each do |post|
      post.with_lock do
        tags = (post.tag_array - normalized_antecedent + normalized_consequent).join(" ")
        post.update(tag_string: tags)
      end
    end
  end

  # this can't handle negated tags or other special cases
  def migrate_blacklists(normalized_antecedent, normalized_consequent)
    query = normalized_antecedent
    adds = normalized_consequent
    arel = query.inject(User.none) do |scope, x|
      scope.or(User.where("blacklisted_tags like ?", "%" + x.to_escaped_for_sql_like + "%"))
    end

    arel.find_each do |user|
      changed = false

      begin
        repl = user.blacklisted_tags.split(/\r\n|\r|\n/).map do |line|
          list = Tag.scan_tags(line)

          if (list & query).size != query.size
            next line
          end

          changed = true
          (list - query + adds).join(" ")
        end

        if changed
          user.update(blacklisted_tags: repl.join("\n"))
        end
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
    end
  end
end
