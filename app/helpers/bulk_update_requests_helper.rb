module BulkUpdateRequestsHelper
  def approved?(command, antecedent, consequent)
    return false unless CurrentUser.is_admin?

    case command
    when :create_alias
      TagAlias.where(antecedent_name: antecedent, consequent_name: consequent, status: %w(active processing queued)).exists?

    when :create_implication
      TagImplication.where(antecedent_name: antecedent, consequent_name: consequent, status: %w(active processing queued)).exists?

    when :remove_alias
      TagAlias.where(antecedent_name: antecedent, consequent_name: consequent, status: "deleted").exists? || !TagAlias.where(antecedent_name: antecedent, consequent_name: consequent).exists?

    when :remove_implication
      TagImplication.where(antecedent_name: antecedent, consequent_name: consequent, status: "deleted").exists? || !TagImplication.where(antecedent_name: antecedent, consequent_name: consequent).exists?

    when :change_category
      tag, category = antecedent, consequent
      Tag.where(name: tag, category: Tag.categories.value_for(category)).exists?

    else
      false
    end
  end

  def failed?(command, antecedent, consequent)
    return false unless CurrentUser.is_admin?

    case command
    when :create_alias
      TagAlias.where(antecedent_name: antecedent, consequent_name: consequent).where("status like ?", "error: %").exists?

    when :create_implication
      TagImplication.where(antecedent_name: antecedent, consequent_name: consequent).where("status like ?", "error: %").exists?

    else
      false
    end
  end

  def collect_script_tags(tokenized)
    names = ::Set.new()
    tokenized.each do |cmd, arg1, arg2|
      case cmd
      when :create_alias, :create_implication, :remove_alias, :remove_implication
        names.add(arg1)
        names.add(arg2)
      when :change_category, :nuke_tag
        names.add(arg1)
      end
    end
    Tag.find_by_name_list(names)
  end

  def script_tag_links(cmd, arg1, arg2, script_tags)
    arg1_count = script_tags[arg1].try(:post_count).to_i
    arg2_count = script_tags[arg2].try(:post_count).to_i

    case cmd
    when :create_alias, :create_implication, :remove_alias, :remove_implication
      "[[#{arg1}]] (#{arg1_count}) -> [[#{arg2}]] (#{arg2_count})"

    when :mass_update
      "[[#{arg1}]] -> [[#{arg2}]]"

    when :nuke_tag
      "[[#{arg1}]] (#{arg1_count})"

    when :change_category
      "[[#{arg1}]] (#{arg1_count}) -> #{arg2}"
    end
  end

  def script_with_line_breaks(bur, with_decorations:)
    cache_key = "#{CurrentUser.is_admin? ? 'mod' : ''}#{with_decorations ? 'color' : ''}#{bur.updated_at}"
    Cache.fetch(cache_key, expires_in: 1.hour) do
      script_tokenized = BulkUpdateRequestImporter.tokenize(bur.script)
      script_tags = collect_script_tags(script_tokenized)
      script_tokenized.map do |cmd, arg1, arg2, arg3|
        if with_decorations && approved?(cmd, arg1, arg2)
          btag = "[color=green][s]"
          etag = "[/s][/color]"
        elsif with_decorations && failed?(cmd, arg1, arg2)
          btag = '[color=red][s]'
          etag = "[/s][/color]"
        end
        links = script_tag_links(cmd, arg1, arg2, script_tags)
        "#{btag}#{cmd.to_s.tr("_", " ")} #{links}#{arg3 if bur.is_pending?}#{etag}"
      end.join("\n")
    rescue BulkUpdateRequestImporter::Error
      "!!!!!!Invalid Script!!!!!!"
    end
  end
end
