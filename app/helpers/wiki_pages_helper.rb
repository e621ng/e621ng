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

  def wiki_page_post_previews(wiki_page)
    tag.section(id: "wiki-page-posts", class: "posts-container") do
      if Post.fast_count(wiki_page.title) > 0
        view_all_link = link_to("view all", posts_path(tags: wiki_page.title))
        header = tag.h2("Posts (#{view_all_link})".html_safe, class: "posts-container-header")
        header + wiki_page.post_set.presenter.post_previews_html(self)
      end
    end
  end
end
