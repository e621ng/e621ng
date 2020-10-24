class TagTypeVersion < ApplicationRecord
  belongs_to :tag
  belongs_to_creator

  module SearchMethods
    def search(params = {})
      q = super.includes(:creator, :tag)

      if params[:tag].present?
        tag = Tag.find_by_normalized_name(params[:tag])
        q = q.where(tag_id: tag.id) if tag
      end

      if params[:user_id].present?
        q = q.where('creator_id = ?', params[:user_id])
      end
      if params[:user_name].present?
        name = User.find_by_name(params[:user_name])
        q = q.where('creator_id = ? ', name.id) if id
      end

      q = q.order(id: :desc)

      q
    end
  end

  extend SearchMethods
end
