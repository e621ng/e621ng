# frozen_string_literal: true

# FavoriteEvent records are created exclusively by PostgreSQL triggers on the
# favorites table. ActiveRecord cannot create them directly because the table
# uses a composite primary key (event_id, created_at) with no 'id' column.
#
# This factory creates a FavoriteEvent by adding a favorite via FavoriteManager,
# causing the insert trigger to fire, then returns the resulting record.
# NOTE: Both build() and create() persist DB records because the trigger fires
# during initialization.
FactoryBot.define do
  factory :favorite_event do
    skip_create

    transient do
      user { create(:user) }
      post { create(:post) }
    end

    initialize_with do
      FavoriteManager.add!(user: user, post: post)
      FavoriteEvent.where(user_id: user.id, post_id: post.id, action: 1).last
    end
  end
end
