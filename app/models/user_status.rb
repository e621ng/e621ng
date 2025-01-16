# frozen_string_literal: true

class UserStatus < ApplicationRecord
  belongs_to :user

  def self.for_user(user_id)
    where("user_statuses.user_id = ?", user_id)
  end
end
