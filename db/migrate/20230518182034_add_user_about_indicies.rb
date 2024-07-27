# frozen_string_literal: true

class AddUserAboutIndicies < ActiveRecord::Migration[7.0]
  def up
    add_index :users, "(to_tsvector('english', profile_about))", using: :gin
    add_index :users, "(to_tsvector('english', profile_artinfo))", using: :gin
    execute("CREATE INDEX index_users_on_lower_profile_about_trgm ON users USING gin ((lower(profile_about)) gin_trgm_ops)")
    execute("CREATE INDEX index_users_on_lower_profile_artinfo_trgm ON users USING gin ((lower(profile_artinfo)) gin_trgm_ops)")
  end
end
