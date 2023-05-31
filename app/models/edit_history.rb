class EditHistory < ApplicationRecord
  self.table_name = "edit_histories"
  belongs_to :versionable, polymorphic: true
  belongs_to :user

  TYPE_MAP = {
    comment: "Comment",
    forum: "ForumPost",
    blip: "Blip",
  }.freeze

  EDIT_MAP = {
    hide: "Hidden",
    unhide: "Unhidden",
    stick: "Stickied",
    unstick: "Unstickied",
    mark_warning: "Marked For Warning",
    wark_record: "Marked For Record",
    mark_ban: "Marked For Ban",
    unmark: "Unmarked",
  }.freeze

  KNOWN_TYPES = %i[
    comment
    forum_post
    blip
  ].freeze

  KNOWN_EDIT_TYPES = %i[
    hide
    unhide
    stick
    unstick
    mark_warning
    mark_record
    mark_ban
    unmark
  ].freeze

  def pretty_edit_type
    edit_type.titleize
  end

  def previous_version(versions)
    return nil if version == 1 || (index = versions.index(self)) < 1
    versions[index - 1]
  end

  def text_content
    EDIT_MAP[edit_type.to_sym] || pretty_edit_type
  end

  def is_contentful?
    %w[original edit].include?(edit_type)
  end
end
