# frozen_string_literal: true

class SetUserTextDefaults < ActiveRecord::Migration[6.1]
  def up
    change_column :users, :profile_about, :text, default: ""
    change_column :users, :profile_artinfo, :text, default: ""
    User.without_timeout do
      User.where(profile_about: nil).in_batches.update_all(profile_about: "")
      User.where(profile_artinfo: nil).in_batches.update_all(profile_artinfo: "")
    end
  end
end
