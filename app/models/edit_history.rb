# frozen_string_literal: true

class EditHistory < ApplicationRecord
  self.table_name = "edit_histories"
  belongs_to :versionable, polymorphic: true
  belongs_to :user

  TYPE_MAP = {
    comment: "Comment",
    forum: "ForumPost",
    blip: "Blip",
  }.freeze

  module SearchMethods
    def search(params)
      q = super

      q = q.attribute_matches(:body, params[:body_matches])
      q = q.attribute_matches(:subject, params[:subject_matches])

      if params[:versionable_type].present?
        q = q.where(versionable_type: params[:versionable_type])
      end

      if params[:versionable_id].present?
        q = q.where(versionable_id: params[:versionable_id])
      end

      q = q.where_user(:user_id, :editor, params)

      if params[:ip_addr].present?
        q = q.where("ip_addr <<= ?", params[:ip_addr])
      end

      q.apply_basic_order(params)
    end
  end

  extend SearchMethods
end
