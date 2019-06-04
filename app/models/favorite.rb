class Favorite < ApplicationRecord
  class Error < Exception
  end

  belongs_to :post
  belongs_to :user
  user_status_counter :favorite_count, foreign_key: :user_id
  scope :for_user, ->(user_id) {where("user_id = #{user_id.to_i}")}
end
