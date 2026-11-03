# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "linked artist methods" do
    let(:uploader) { create(:user) }
    let(:other) { create(:user) }

    let!(:post) do
      counts = [
        artist_tag("small_(artist)", post_count: 10, linked_user: uploader),
        artist_tag("big_(artist)", post_count: 500, linked_user: other),
        artist_tag("unlinked_(artist)", post_count: 900),
        artist_tag("no_entry_(artist)", post_count: 900, linked_user: :none),
      ]
      post = create(:post, tag_string: "small_(artist) big_(artist) unlinked_(artist) no_entry_(artist) solo", uploader: uploader)
      counts.each(&:call)
      Post.find(post.id)
    end

    def artist_queries(&)
      queries = []
      callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?(%(FROM "artists")) }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &)
      queries
    end

    def artist_tag(name, post_count: 0, linked_user: nil)
      create(:artist_tag, name: name)
      create(:artist, name: name, linked_user: linked_user) unless linked_user == :none
      -> { Tag.where(name: name).update_all(post_count: post_count) }
    end

    it "returns the linked artists" do
      expect(post.artists_with_linked_users.map(&:name)).to contain_exactly("small_(artist)", "big_(artist)")
      expect(post.linked_users).to contain_exactly(uploader.id, other.id)
      expect(post.uploader_linked_artists).to eq(["small_(artist)"])
    end

    it "returns verified artist tags with ids, most posts first" do
      tags = post.verified_artist_tags
      expect(tags.map(&:name)).to eq(["big_(artist)", "small_(artist)"])
      expect(tags.map(&:id)).to eq(Tag.where(name: tags.map(&:name)).order(post_count: :desc).pluck(:id))
    end

    it "orders verified artist tags with equal post counts by name" do
      Tag.where(name: %w[small_(artist) big_(artist)]).update_all(post_count: 50)
      expect(Post.find(post.id).verified_artist_tags.map(&:name)).to eq(["big_(artist)", "small_(artist)"])
    end

    it "looks up all artists in a single query" do
      queries = artist_queries do
        post.artists_with_linked_users
        post.uploader_linked_artists
        post.verified_artist_tags
        post.linked_users
      end
      expect(queries.size).to eq(1)
    end

    it "makes no artist query for posts without artist tags" do
      plain = Post.find(create(:post, tag_string: "solo").id)
      expect(artist_queries { plain.verified_artist_tags }).to be_empty
    end

    it "clears the memoized artists on reload" do
      expect(post.uploader_linked_artists).to eq(["small_(artist)"])
      Artist.find_by(name: "small_(artist)").update_columns(linked_user_id: nil)
      post.reload
      expect(post.uploader_linked_artists).to eq([])
      expect(post.verified_artist_tags.map(&:name)).to eq(["big_(artist)"])
      expect(post.linked_users).to eq([other.id])
    end
  end
end
