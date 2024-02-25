# frozen_string_literal: true

class MetaSearches::Tag
  MAX_RESULTS = 25
  attr_reader :search, :tags, :tag_aliases, :tag_implications

  def initialize(search_params)
    @search = search_params[:name] || ""
  end

  def load_all
    return if search.blank?

    load_tags
    load_tag_aliases
    load_tag_implications
  end

  def load_tags
    @tags = ::Tag.name_matches(search).limit(MAX_RESULTS)
  end

  def load_tag_aliases
    @tag_aliases = TagAlias.name_matches(search).limit(MAX_RESULTS)
  end

  def load_tag_implications
    @tag_implications = TagImplication.name_matches(search).limit(MAX_RESULTS)
  end
end
