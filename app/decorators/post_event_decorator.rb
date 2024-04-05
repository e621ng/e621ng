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
    end
  end
end
