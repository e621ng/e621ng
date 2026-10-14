# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         Artist Post Reindexing                              #
# --------------------------------------------------------------------------- #

RSpec.describe Artist do
  include_context "as admin"

  describe "#update_posts_index" do
    it "enqueues a reindex when a user is linked" do
      artist = create(:artist)
      linked = create(:user)
      expect do
        artist.update!(linked_user_id: linked.id)
      end.to enqueue_sidekiq_job(ArtistReindexJob).with(artist.name)
    end

    it "enqueues a reindex when a linked user is removed" do
      linked = create(:user)
      artist = create(:artist, linked_user_id: linked.id)
      expect do
        artist.update!(linked_user_id: nil)
      end.to enqueue_sidekiq_job(ArtistReindexJob).with(artist.name)
    end

    it "does NOT enqueue a reindex when linked_user_id is unchanged" do
      artist = create(:artist)
      expect do
        artist.update!(name: "#{artist.name}_renamed")
      end.not_to enqueue_sidekiq_job(ArtistReindexJob)
    end
  end
end
