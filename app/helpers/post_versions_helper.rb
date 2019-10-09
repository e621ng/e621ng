module PostVersionsHelper
  def post_source_diff(post_version)
    diff = post_version.diff_sources(post_version.previous)
    html = '<span class="diff-list">'

    diff[:added_sources].each do |source|
      prefix = '<div><ins>+'
      html << prefix + wordbreakify(source) + '</ins></div>'
      html << " "
    end
    diff[:removed_sources].each do |source|
      prefix = '<div><del>-'
      html << prefix + wordbreakify(source) + '</del></div>'
      html << " "
    end
    diff[:unchanged_sources].each do |source|
      html << '<div>' + wordbreakify(source) + '</div>'
      html << " "
    end

    html << "</span>"
    html.html_safe
  end

  def post_version_diff(post_version)
    diff = post_version.diff(post_version.previous)
    html = '<span class="diff-list">'

    diff[:added_tags].each do |tag|
      prefix = diff[:obsolete_added_tags].include?(tag) ? '<ins class="obsolete">+' : '<ins>+'
      html << prefix + link_to(tag, posts_path(:tags => tag)) + '</ins>'
      html << " "
    end
    diff[:removed_tags].each do |tag|
      prefix = diff[:obsolete_removed_tags].include?(tag) ? '<del class="obsolete">-' : '<del>-'
      html << prefix + link_to(tag, posts_path(:tags => tag)) + '</del>'
      html << " "
    end
    diff[:unchanged_tags].each do |tag|
      html << '<span>' + link_to(tag, posts_path(:tags => tag)) + '</span>'
      html << " "
    end

    html << "</span>"
    html.html_safe
  end

  def post_version_locked_diff(post_version)
    diff = post_version.diff(post_version.previous)
    html = '<span class="diff-list">'

    diff[:added_locked_tags].each do |tag|
      prefix = '<ins>+'
      html << prefix + link_to(tag, posts_path(:tags => tag)) + '</ins>'
      html << " "
    end
    diff[:removed_locked_tags].each do |tag|
      prefix = '<del>-'
      html << prefix + link_to(tag, posts_path(:tags => tag)) + '</del>'
      html << " "
    end
    diff[:unchanged_locked_tags].each do |tag|
      html << '<span>' + link_to(tag, posts_path(:tags => tag)) + '</span>'
      html << " "
    end

    html << "</span>"
    html.html_safe
  end
end
