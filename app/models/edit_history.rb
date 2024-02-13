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

  def previous_contentful_edit(versions)
    return nil if version == 1
    previous = previous_version(versions)
    return previous if previous.present?
    # we might be on a page that doesn'template contain the most recent contentful edit, query to try to find it
    EditHistory.where(versionable_id: versionable_id, versionable_type: versionable_type, edit_type: %w[original edit]).and(EditHistory.where(EditHistory.arel_table[:version].lt(version))).last
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

  def html_name
    case versionable_type
    when "ForumPost"
      "Forum Post ##{versionable_id}"
    when "Comment"
      "Comment ##{versionable_id}"
    when "Blip"
      "Blip ##{versionable_id}"
    else
      "#{versionable_type} ##{versionable_id}"
    end
  end

  def link(template)
    case versionable_type
    when "ForumPost"
      template.forum_post_path(versionable_id)
    when "Comment"
      template.comment_path(versionable_id)
    when "Blip"
      template.blip_path(versionable_id)
    else
      template.edit_histories_path(versionable_type: versionable_type, versionable_id: versionable_id)
    end
  end

  def html_link(template)
    template.link_to(html_name, link(template))
  end

  def html_title(template)
    template.tag.h1 do
      template.tag.span("Edits for ") + html_link(template)
    end
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

      q = q.where_user(:user_id, :user, params)

      if params[:ip_addr].present?
        q = q.where("ip_addr <<= ?", params[:ip_addr])
      end

      q.apply_basic_order(params)
    end
  end

  extend SearchMethods
end
