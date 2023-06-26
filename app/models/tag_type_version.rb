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

      if params[:user_id].present?
        user = User.find_by_id(params[:user_id])
        q = q.where(creator: user)
      end
      if params[:user_name].present?
        user = User.find_by_name(params[:user_name])
        q = q.where(creator: user)
      end

      q.order(id: :desc)
    end
  end

  extend SearchMethods
end
