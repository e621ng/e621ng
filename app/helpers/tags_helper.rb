module TagsHelper
  def alias_and_implication_list(tag)
    return "" if tag.nil?

    html = ""

    if tag.antecedent_alias
      html << "<p class='hint'>This tag has been aliased to "
      html << link_to(tag.antecedent_alias.consequent_name, show_or_new_wiki_pages_path(:title => tag.antecedent_alias.consequent_name))
      html << " (#{link_to "learn more", wiki_pages_path(title: "e621:tag_aliases")}).</p>"
    end

    if tag.consequent_aliases.present?
      html << "<p class='hint'>The following tags are aliased to this tag: "
      html << raw(tag.consequent_aliases.map {|x| link_to(x.antecedent_name, show_or_new_wiki_pages_path(:title => x.antecedent_name))}.join(", "))
      html << " (#{link_to "learn more", wiki_pages_path(title: "e621:tag_aliases")}).</p>"
    end

    if tag.antecedent_implications.present?
      html << "<p class='hint'>This tag implicates "
      html << raw(tag.antecedent_implications.map {|x| link_to(x.consequent_name, show_or_new_wiki_pages_path(:title => x.consequent_name))}.join(", "))
      html << " (#{link_to "learn more", wiki_pages_path(title: "e621:tag_implications")}).</p>"
    end

    if tag.consequent_implications.present?
      html << "<p class='hint'>The following tags implicate this tag: "
      html << raw(tag.consequent_implications.map {|x| link_to(x.antecedent_name, show_or_new_wiki_pages_path(:title => x.antecedent_name))}.join(", "))
      html << " (#{link_to "learn more", wiki_pages_path(title: "e621:tag_implications")}).</p>"
    end

    html.html_safe
  end

  def format_transitive_item(transitive)
    html = "<strong class=\"text-error\">#{transitive[0].to_s.titlecase}</strong> ".html_safe
    if transitive[0] == :alias
      html << "#{transitive[2]} -> #{transitive[3]} will become #{transitive[2]} -> #{transitive[4]}"
    else
      html << "#{transitive[2]} +> #{transitive[3]} will become #{transitive[4]} +> #{transitive[5]}"
    end
    html
  end
end
