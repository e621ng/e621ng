# frozen_string_literal: true

class PostEventDecorator < ApplicationDecorator
  def self.collection_decorator_class
    PaginatedDecorator
  end

  delegate_all

  def format_description
    vals = object.extra_data

    case object.action
    when "deleted", "flag_created"
      "#{vals['reason']}"
    when "favorites_moved"
      "Target: post ##{vals['parent_id']}"
    when "favorites_received"
      "From: post ##{vals['child_id']}"
    when "replacement_promoted"
      "From: post ##{vals['source_post_id']}"
    when "changed_bg_color"
      "To: #{vals['bg_color'] || 'None'}"
    when "owner_changed"
      old_owner = "\"#{User.id_to_name(vals['old_owner'])}\":/users/#{vals['old_owner']}"
      new_owner = "\"#{User.id_to_name(vals['new_owner'])}\":/users/#{vals['new_owner']}"
      "#{old_owner} → #{new_owner}"
    end
  end
end
