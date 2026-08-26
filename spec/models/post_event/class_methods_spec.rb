# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          PostEvent Class Methods                            #
# --------------------------------------------------------------------------- #

RSpec.describe PostEvent do
  include_context "as admin"

  let(:post)    { create(:post) }
  let(:creator) { create(:user) }

  # -------------------------------------------------------------------------
  # .add
  # -------------------------------------------------------------------------
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

  # -------------------------------------------------------------------------
  # .search_options_for
  # -------------------------------------------------------------------------
  describe ".search_options_for" do
    it "returns all action keys for a moderator" do
      moderator = create(:moderator_user)
      expect(PostEvent.search_options_for(moderator)).to eq(PostEvent.actions.keys)
    end

    it "excludes mod-only actions for a regular member" do
      member  = create(:user)
      options = PostEvent.search_options_for(member)
      PostEvent::MOD_ONLY_SEARCH_ACTIONS.each do |mod_only_action|
        expect(options).not_to include(mod_only_action)
      end
    end

    it "excludes PROTECTED_ACTION_KEYS for a regular member" do
      member  = create(:user)
      options = PostEvent.search_options_for(member)
      PostEvent::PROTECTED_ACTION_KEYS.each do |protected_key|
        expect(options).not_to include(protected_key)
      end
    end

    it "includes non-protected, non-mod-only actions for a regular member" do
      member  = create(:user)
      options = PostEvent.search_options_for(member)
      expect(options).to include("deleted", "approved", "flag_created")
    end
  end
end
