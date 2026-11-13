# frozen_string_literal: true

class PostEventDecorator < ApplicationDecorator
  include(Rails.application.routes.url_helpers)

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
    when "replacement_accepted"
      %("post replacement ##{vals['replacement_id']}":[#{post_replacements_path(search: { id: vals['replacement_id'] })}]\nMD5: #{vals['old_md5']} → #{vals['new_md5']})
    when "replacement_rejected"
      %("post replacement ##{vals['replacement_id']}":[#{post_replacements_path(search: { id: vals['replacement_id'] })}])
    when "replacement_promoted"
      content = ""
      if vals["replacement_id"]
        content += %("post replacement ##{vals['replacement_id']}":[#{post_replacements_path(search: { id: vals['replacement_id'] })}]\n)
      end
      content + "From: post ##{vals['source_post_id']}"
    when "replacement_deleted"
      %("post replacement ##{vals['replacement_id']}":[#{post_replacements_path(search: { id: vals['replacement_id'] })}]\nMD5: #{vals['md5']})
    when "changed_bg_color"
      "To: #{vals['bg_color'] || 'None'}"
    when "owner_changed"
      old_name = User.id_to_name(vals["old_owner"])
      new_name = User.id_to_name(vals["new_owner"])
      old_owner = %("#{old_name}":[#{user_path(id: vals['old_owner'])}])
      new_owner = %("#{new_name}":[#{user_path(id: vals['new_owner'])}])
      "#{old_owner} → #{new_owner}"
    when "replacement_moved"
      %("post replacement ##{vals['replacement_id']}":[#{post_replacements_path(search: { id: vals['replacement_id'] })}]\nFrom post ##{vals['old_post']} to post ##{vals['new_post']})
    end
  end
end
