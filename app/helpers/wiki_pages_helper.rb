# frozen_string_literal: true

module WikiPagesHelper
  def link_to_wiki_or_new(text, tag = text)
    link_to(text, show_or_new_wiki_pages_path(title: tag))
  end

  def multiple_link_to_wiki_or_new(tags)
    safe_join(tags.map { |tag| link_to_wiki_or_new(tag) }, ", ")
  end

  def wiki_page_alias_and_implication_list(wiki_page)
    render "tags/alias_and_implication_list", tag: wiki_page.tag || Tag.new(name: wiki_page.title)
  end

  def wiki_page_outline(wiki_content, allow_color: true, max_thumbs: 75)
    WikiTableOfContents.new(format_text(wiki_content.body, allow_color: allow_color, max_thumbs: max_thumbs).to_s)
  end
end
