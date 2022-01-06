class PostEventDecorator < ApplicationDecorator
  delegate_all

  def format_description
    vals = object.extra_data

    case object.action
    when "deleted", "flag_created"
      "Reason: #{vals['reason']}"
    when "favorites_moved"
      "Target: post ##{vals['parent_id']}"
    when "favorites_recieved"
      "Source: post ##{vals['child_id']}"
    end
  end
end
