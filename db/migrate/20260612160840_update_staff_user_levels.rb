# frozen_string_literal: true

class UpdateStaffUserLevels < ActiveRecord::Migration[8.1]
  def up
    User.without_timeout do
      User.where(level: 50).update_all(level: 80) # Admin
      User.where(level: 40).update_all(level: 70) # Moderator
      User.where(level: 35).update_all(level: 60) # Janitor
      User.where(level: 34).update_all(level: 40) # Former Staff
    end
  end

  def down
    User.without_timeout do
      User.where(level: 50).update_all(level: 20) # Staff become Members, for safety
      User.where(level: 40).update_all(level: 34) # Former Staff
      User.where(level: 60).update_all(level: 35) # Janitor
      User.where(level: 70).update_all(level: 40) # Moderator
      User.where(level: 80).update_all(level: 50) # Admin
    end
  end
end
