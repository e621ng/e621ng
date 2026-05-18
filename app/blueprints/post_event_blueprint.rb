# frozen_string_literal: true

class PostEventBlueprint < Blueprinter::Base
  identifier :id

  fields :post_id, :action, :created_at

  field :creator_id do |post_event|
    post_event.is_creator_visible?(CurrentUser.user) ? post_event.creator_id : nil
  end
end
