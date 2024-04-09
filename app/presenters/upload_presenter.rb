# frozen_string_literal: true

class UploadPresenter < Presenter
  attr_reader :upload
  delegate :inline_tag_list_html, to: :tag_set_presenter

  def initialize(upload)
    @upload = upload
  end

  def tag_set_presenter
    @tag_set_presenter ||= TagSetPresenter.new(normalize_tags(upload.tag_string.split))
  end

  def strip_metatags(tags)
    tags.grep_v(/\A(?:rating|-?parent|-?locked|-?pool|newpool|-?set|-?fav|-?child|upvote|downvote):/i)
  end

  def normalize_tags(tags)
    tags = tags.map(&:downcase)
    tags = strip_metatags(tags)
    tags.map { |tag| tag.gsub(/(?:#{TagCategory::ALL_NAMES_REGEX}):/, "") }
  end
end
