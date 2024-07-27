# frozen_string_literal: true

class PostEventSerializer < ActiveModel::Serializer
  def creator_id
    object.is_creator_visible?(CurrentUser.user) ? object.creator_id : nil
  end

  attributes :id, :creator_id, :post_id, :action, :created_at
end
