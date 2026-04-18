# frozen_string_literal: true

class Favorite < ApplicationRecord
  class Error < StandardError
  end

  class HiddenError < User::PrivilegeError
    def initialize(msg = "This users favorites are hidden")
      super
    end
  end

  belongs_to :post
  belongs_to :user
  user_status_counter :favorite_count, foreign_key: :user_id
  scope :for_user, ->(user_id) { where("user_id = #{user_id.to_i}") }
end
