# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       FavoriteEvent Factory                                 #
# --------------------------------------------------------------------------- #
#
# FavoriteEvent records are created exclusively via PostgreSQL triggers on the
# favorites table — there is no direct ActiveRecord create path. The factory
# uses FavoriteManager.add! to exercise the trigger and returns the resulting
# record. Both build() and create() persist DB records as a consequence.

RSpec.describe FavoriteEvent do
  include_context "as member"

  describe "factory" do
    it "produces a persisted record" do
      event = create(:favorite_event)
      expect(event).to be_persisted
    end

    it "records an insert action" do
      event = create(:favorite_event)
      expect(event.action).to eq(1)
    end

    it "stores the correct user_id and post_id" do
      user  = create(:user)
      post  = create(:post)
      event = create(:favorite_event, user: user, post: post)
      expect(event.user_id).to eq(user.id)
      expect(event.post_id).to eq(post.id)
    end
  end
end
