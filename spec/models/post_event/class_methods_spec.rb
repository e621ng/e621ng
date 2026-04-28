# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostEvent do
  include_context "as admin"

  let(:post)    { create(:post) }
  let(:creator) { create(:user) }

  # --------------------------------------------------------------------------- #
  #                             PostEvent.add                                   #
  # --------------------------------------------------------------------------- #

  describe ".add" do
    it "creates a persisted record" do
      expect { PostEvent.add(post.id, creator, :deleted) }.to change(PostEvent, :count).by(1)
    end

    it "sets post_id, creator, and action correctly" do
      PostEvent.add(post.id, creator, :deleted)
      event = PostEvent.last
      expect(event.post_id).to eq(post.id)
      expect(event.creator).to eq(creator)
      expect(event.action).to eq("deleted")
    end

    it "stores extra_data when provided" do
      PostEvent.add(post.id, creator, :flag_created, reason: "rule violation")
      expect(PostEvent.last[:extra_data]).to include("reason" => "rule violation")
    end

    it "accepts a string action as well as a symbol" do
      PostEvent.add(post.id, creator, "approved")
      expect(PostEvent.last.action).to eq("approved")
    end
  end

  # --------------------------------------------------------------------------- #
  #                        PostEvent.search_options_for                         #
  # --------------------------------------------------------------------------- #

  describe ".search_options_for" do
    let(:mod_only_actions) { %w[comment_locked comment_unlocked comment_disabled comment_enabled] }

    it "returns all action keys for a moderator" do
      moderator = create(:moderator_user)
      options   = PostEvent.search_options_for(moderator)
      expect(options).to include(*mod_only_actions)
      expect(options.length).to eq(PostEvent.actions.length)
    end

    it "excludes mod-only actions for a regular member" do
      member  = create(:user)
      options = PostEvent.search_options_for(member)
      expect(options).not_to include(*mod_only_actions)
    end

    it "includes all non-mod-only actions for a regular member" do
      member           = create(:user)
      expected_actions = PostEvent.actions.keys - mod_only_actions
      options          = PostEvent.search_options_for(member)
      expect(options).to include(*expected_actions)
    end
  end
end
