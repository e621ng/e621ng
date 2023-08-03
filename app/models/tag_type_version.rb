class TagTypeVersion < ApplicationRecord
  belongs_to :tag
  belongs_to_creator

  module SearchMethods
    def search(params)
      q = super.includes(:creator, :tag)

      if params[:tag].present?
        tag = Tag.find_by_normalized_name(params[:tag])
        q = q.where(tag: tag)
      end

      q = q.where_user(:creator_id, :user, params)

      q.order(id: :desc)
    end
  end

  extend SearchMethods
end
