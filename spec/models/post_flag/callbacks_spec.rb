# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostFlag do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # before_save :update_post
  # -------------------------------------------------------------------------
  describe "#update_post (before_save)" do
    it "sets post.is_flagged to true when a flag is created" do
      post = create(:post, is_flagged: false)
      create(:post_flag_reason)
      create(:post_flag, post: post)
      expect(post.reload.is_flagged).to be true
    end

    it "does not raise an error when the post is already flagged" do
      post = create(:flagged_post)
      create(:post_flag_reason)
      expect { create(:post_flag, post: post) }.not_to raise_error
    end
  end

  # -------------------------------------------------------------------------
  # after_create :create_post_event
  # -------------------------------------------------------------------------
  describe "#create_post_event (after_create)" do
    it "creates a PostEvent with action flag_created for a regular flag" do
      create(:post_flag_reason)
      expect { create(:post_flag) }.to change(PostEvent, :count).by(1)
      expect(PostEvent.last.action).to eq("flag_created")
    end

    it "records the flag reason in the PostEvent extra_data" do
      create(:post_flag_reason)
      flag = create(:post_flag)
      event = PostEvent.where(post_id: flag.post_id).last
      expect(event.extra_data["reason"]).to be_present
    end

    it "does not create a PostEvent for deletion flags" do
      expect { create(:deletion_post_flag) }.not_to change(PostEvent, :count)
    end
  end

  # -------------------------------------------------------------------------
  # after_commit :index_post
  # -------------------------------------------------------------------------
  describe "#index_post (after_commit)" do
    it "calls update_index on the post after the flag is committed" do
      post = create(:post)
      create(:post_flag_reason)
      allow(post).to receive(:update_index).and_call_original
      create(:post_flag, post: post)
      expect(post).to have_received(:update_index).at_least(:once)
    end
  end
end
