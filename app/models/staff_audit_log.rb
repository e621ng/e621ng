# frozen_string_literal: true

class StaffAuditLog < ApplicationRecord
  belongs_to :user, class_name: "User"

  def self.log(category, user, details = {})
    create(user: user, action: category.to_s, values: details)
  end
end
