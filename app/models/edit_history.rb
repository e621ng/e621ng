class EditHistory < ApplicationRecord
  self.table_name = "edit_histories"
  belongs_to :versionable, polymorphic: true
  belongs_to :user

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

  # rubocop:disable Rails/OutputSafety
  def text_content
    if is_contentful?
      return subject if subject.present?
      return body
    end
    "<b>#{EDIT_MAP[edit_type.to_sym] || pretty_edit_type}</b>".html_safe
  end
  # rubocop:enable Rails/OutputSafety

  def is_contentful?
    %w[original edit].include?(edit_type)
  end

  def page(limit = 20)
    limit = limit.to_i
    return 1 if limit <= 0
    (version / limit).ceil + 1
  end

  module SearchMethods
    def hidden
      where(edit_type: "hide")
    end

    def marked
      where(edit_type: %w[mark_warning mark_record mark_ban])
    end

    def edited
      where(edit_type: "edit")
    end

    def original
      where(edit_type: "original", version: 1).first
    end

    def search(params)
      q = super

      if params[:versionable_type].present?
        q = q.where(versionable_type: params[:versionable_type])
      end

      if params[:versionable_id].present?
        q = q.where(versionable_id: params[:versionable_id])
      end

      if params[:edit_type].present?
        q = q.where(edit_type: params[:edit_type])
      else
        q = q.where.not(edit_type: "original")
      end

      if params[:user_id].present?
        q = q.where(user_id: params[:user_id])
      end

      if params[:user_name].present?
        q = q.where("user_id = (select _.id from users _ where lower(_.name) = ?)", params[:user_name].downcase)
      end

      if params[:ip_addr].present?
        q = q.where("ip_addr <<= ?", params[:ip_addr])
      end

      q.apply_basic_order(params)
    end
  end

  extend SearchMethods
end
