# frozen_string_literal: true

module PostVersionsHelper
  def post_source_diff(post_version)
    diff = post_version.diff_sources(post_version.previous)
    new_sources = post_version.source.to_s.split("\n")
    added = diff[:added_sources].to_set

    changes = new_sources.map do |source|
      if added.include?(source)
        tag.div(tag.ins(diff_source_link("+", source)))
      else
        tag.div(post_source_tag(source))
      end
    end

    diff[:removed_sources].each do |source|
      changes << tag.div(tag.del(diff_source_link("-", source)))
    end

    tag.div(safe_join(changes, " "), class: "diff-list")
  end

  def diff_source_link(sign, source)
    safe_join([tag.span(sign, class: "diff-sign"), post_source_tag(source)])
  end

  def post_version_diff(post_version)
    diff = post_version.diff(post_version.previous)
    all_names = (diff[:added_tags] + diff[:removed_tags] + diff[:unchanged_tags]).sort
    categories = post_version.tag_categories
    added = diff[:added_tags].to_set
    removed = diff[:removed_tags].to_set
    obsolete_added = diff[:obsolete_added_tags].to_set
    obsolete_removed = diff[:obsolete_removed_tags].to_set

    changes = all_names.map do |tag_name|
      if added.include?(tag_name)
        classes = obsolete_added.include?(tag_name) ? "obsolete" : nil
        tag.ins(diff_tag_link("+", tag_name, tag_name, categories), class: classes)
      elsif removed.include?(tag_name)
        classes = obsolete_removed.include?(tag_name) ? "obsolete" : nil
        tag.del(diff_tag_link("-", tag_name, tag_name, categories), class: classes)
      else
        tag.span(category_tag_link(tag_name, tag_name, categories))
      end
    end

    tag.span(safe_join(changes, " "), class: "diff-list")
  end

  def post_version_locked_diff(post_version)
    diff = post_version.diff(post_version.previous)
    all_names = (diff[:added_locked_tags] + diff[:removed_locked_tags] + diff[:unchanged_locked_tags]).sort
    categories = post_version.tag_categories
    added = diff[:added_locked_tags].to_set
    removed = diff[:removed_locked_tags].to_set

    changes = all_names.map do |tag_name|
      lookup = trim_leading_minus(tag_name)
      if added.include?(tag_name)
        tag.ins(diff_tag_link("+", tag_name, lookup, categories))
      elsif removed.include?(tag_name)
        tag.del(diff_tag_link("-", tag_name, lookup, categories))
      else
        tag.span(category_tag_link(tag_name, lookup, categories))
      end
    end

    tag.span(safe_join(changes, " "), class: "diff-list")
  end

  private

  def diff_tag_link(sign, display_name, lookup_name, categories)
    safe_join([tag.span(sign, class: "diff-sign"), category_tag_link(display_name, lookup_name, categories)])
  end

  def category_tag_link(text, tag_name, categories)
    category = categories[tag_name] || 0
    link_to(text, show_or_new_wiki_pages_path(title: tag_name), class: "tag-type-#{category}")
  end

  def trim_leading_minus(str)
    str.start_with?("-") ? str[1..] : str
  end
end
