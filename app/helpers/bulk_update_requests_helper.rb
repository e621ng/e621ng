module BulkUpdateRequestsHelper
  def approved?(command, antecedent, consequent)
    return false unless CurrentUser.is_moderator?

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
    return false unless CurrentUser.is_moderator?

    case command
    when :create_alias
      TagAlias.where(antecedent_name: antecedent, consequent_name: consequent).where("status like ?", "error: %").exists?

    when :create_implication
      TagImplication.where(antecedent_name: antecedent, consequent_name: consequent).where("status like ?", "error: %").exists?

    else
      false
    end
  end

  def command_to_string(command)
    command.to_s.tr("_", " ")
  end

  def script_with_links(script)
    tokens = AliasAndImplicationImporter.tokenize(script)
    lines = tokens.map do |token|
      case token[0]
      when :create_alias, :create_implication, :remove_alias, :remove_implication, :mass_update
        "#{command_to_string(token[0])} [[#{token[1]}]] -> [[#{token[2]}]] #{token[3]}"

      when :change_category
        "#{command_to_string(token[0])} [[#{token[1]}]] -> #{token[2]} #{token[3]}"

      else
        raise "Unknown token: #{token[0]}"
      end
    end
    lines.join("\n")
  end

  def collect_script_tags(tokenized)
    names = ::Set.new()
    tokenized.each do |cmd, arg1, arg2|
      case cmd
      when :create_alias, :create_implication, :remove_alias, :remove_implication
        names.add(arg1)
        names.add(arg2)
      when :change_category
        names.add(arg1)
      end
    end
    Tag.find_by_name_list(names)
  end

  def script_with_line_breaks(script)
    output = Cache.get(Cache.hash((CurrentUser.is_moderator? ? "mod" : "") + script), 3600) do
      script_tokenized = AliasAndImplicationImporter.tokenize(script)
      script_tags = collect_script_tags(script_tokenized)
      escaped_script = script_tokenized.map do |cmd, arg1, arg2|
        if approved?(cmd, arg1, arg2)
          btag = '<s class="approved">'
          etag = '</s>'
        elsif failed?(cmd, arg1, arg2)
          btag = '<s class="failed">'
          etag = "</s>"
        else
          btag = nil
          etag = nil
        end

        case cmd
        when :create_alias, :create_implication, :remove_alias, :remove_implication
          arg1_count = script_tags[arg1].try(:post_count).to_i
          arg2_count = script_tags[arg2].try(:post_count).to_i

          "#{btag}#{command_to_string(cmd)} " + link_to(arg1, posts_path(:tags => arg1)) + " (#{arg1_count}) -&gt; " + link_to(arg2, posts_path(:tags => arg2)) + " (#{arg2_count})#{etag}"

        when :mass_update
          "#{btag}#{command_to_string(cmd)} " + link_to(arg1, posts_path(:tags => arg1)) + " -&gt; " + link_to(arg2, posts_path(:tags => arg2)) + "#{etag}"

        when :change_category
          arg1_count = script_tags[arg1].try(:post_count).to_i

          "#{btag}#{command_to_string(cmd)} " + link_to(arg1, posts_path(:tags => arg1)) + " (#{arg1_count}) -&gt; (#{arg2})#{etag}"

        end
      end.join("\n")

      escaped_script.gsub(/\n/m, "<br>")
    rescue AliasAndImplicationImporter::Error
      "!!!!!!Invalid Script!!!!!!"
    end

    output.html_safe

  end
end
