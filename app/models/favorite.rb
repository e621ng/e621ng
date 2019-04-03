class Favorite < ApplicationRecord
  class Error < Exception
  end

  belongs_to :post
  belongs_to :user, counter_cache: 'favorite_count'
  scope :for_user, ->(user_id) {where("user_id = #{user_id.to_i}")}
end
