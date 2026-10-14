# frozen_string_literal: true

class UserIpAddress < ApplicationRecord
  belongs_to :user

  def hidden_attributes
    super + %i[subnet]
  end
end
