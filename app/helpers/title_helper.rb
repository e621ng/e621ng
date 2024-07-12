# frozen_string_literal: true

module TitleHelper
  def get_title
    return Danbooru.config.app_name if current_page? root_path
    return content_for(:page_title) + " - " + Danbooru.config.app_name if content_for? :page_title
    ""
  end
end
