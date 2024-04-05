# frozen_string_literal: true

class ApiKey < ApplicationRecord
  belongs_to :user
  validates :user_id, uniqueness: true
  validates :key, uniqueness: true
  has_secure_token :key

  def self.generate!(user)
    create(:user_id => user.id)
  end

  def regenerate!
    regenerate_key
    save
  end
end
