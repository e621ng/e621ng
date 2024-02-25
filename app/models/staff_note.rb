# frozen_string_literal: true

class StaffNote < ApplicationRecord
  belongs_to :creator, class_name: "User"
  belongs_to :user

  module SearchMethods
    def search(params)
      q = super

      if params[:resolved]
        q = q.attribute_matches(:resolved, params[:resolved])
      end

      q = q.where_user(:user_id, :user, params)
      q = q.where_user(:creator_id, :creator, params)

      if params[:without_system_user]&.truthy?
        q = q.where.not(creator: User.system)
      end

      q.apply_basic_order(params)
    end

    def default_order
      order("resolved asc, id desc")
    end
  end

  extend SearchMethods

  def resolve!
    self.resolved = true
    save
  end

  def unresolve!
    self.resolved = false
    save
  end
end
