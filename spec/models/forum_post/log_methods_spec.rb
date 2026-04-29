# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       ForumPost Audit Logging                               #
# --------------------------------------------------------------------------- #

RSpec.describe ForumPost do
  include_context "as moderator"

  let(:creator)   { create(:user) }
  let(:moderator) { create(:moderator_user) }
  let(:topic)     { CurrentUser.scoped(moderator) { create(:forum_topic) } }

  # Create the post as a different user so moderator updates trigger logging.
  def make_post(overrides = {})
    CurrentUser.scoped(creator) { create(:forum_post, topic_id: topic.id, **overrides) }
  end

  # -------------------------------------------------------------------------
  # forum_post_update
  # -------------------------------------------------------------------------
  describe "forum_post_update logging" do
    it "logs forum_post_update when a moderator edits another user's post body" do
      post = make_post
      expect { post.update!(body: "edited body") }.to change(ModAction, :count).by(1)
      expect(ModAction.last.action).to eq("forum_post_update")
    end

    it "includes forum_post_id, forum_topic_id, and creator user_id in the log values" do
      post = make_post
      post.update!(body: "changed")
      log = ModAction.last
      expect(log[:values]).to include(
        "forum_post_id"  => post.id,
        "forum_topic_id" => topic.id,
        "user_id"        => creator.id,
      )
    end

    it "does not log forum_post_update when is_hidden changes (hide/unhide fires instead)" do
      post = make_post
      expect { post.update!(is_hidden: true) }.not_to(change { ModAction.where(action: "forum_post_update").count })
    end

    it "does not log forum_post_update when the creator edits their own post" do
      post = make_post
      CurrentUser.user = creator
      expect { post.update!(body: "self edit") }.not_to(change { ModAction.where(action: "forum_post_update").count })
    end
  end

  # -------------------------------------------------------------------------
  # forum_post_hide / forum_post_unhide
  # -------------------------------------------------------------------------
  describe "hide/unhide logging" do
    it "logs forum_post_hide when hide! is called" do
      post = make_post
      expect { post.hide! }.to change(ModAction, :count).by(1)
      expect(ModAction.last.action).to eq("forum_post_hide")
    end

    it "logs forum_post_unhide when unhide! is called" do
      post = make_post
      post.update_columns(is_hidden: true)
      expect { post.unhide! }.to change(ModAction, :count).by(1)
      expect(ModAction.last.action).to eq("forum_post_unhide")
    end

    it "includes forum_post_id, forum_topic_id, and user_id in hide log values" do
      post = make_post
      post.hide!
      log = ModAction.last
      expect(log[:values]).to include(
        "forum_post_id"  => post.id,
        "forum_topic_id" => topic.id,
        "user_id"        => creator.id,
      )
    end
  end

  # -------------------------------------------------------------------------
  # forum_post_delete
  # -------------------------------------------------------------------------
  describe "forum_post_delete logging" do
    it "logs forum_post_delete when a post is destroyed" do
      post = make_post
      expect { post.destroy! }.to change(ModAction, :count).by(1)
      expect(ModAction.last.action).to eq("forum_post_delete")
    end

    it "includes forum_post_id, forum_topic_id, and user_id in the delete log values" do
      post       = make_post
      post_id    = post.id
      topic_id   = topic.id
      creator_id = creator.id
      post.destroy!
      log = ModAction.last
      expect(log[:values]).to include(
        "forum_post_id"  => post_id,
        "forum_topic_id" => topic_id,
        "user_id"        => creator_id,
      )
    end
  end
end
