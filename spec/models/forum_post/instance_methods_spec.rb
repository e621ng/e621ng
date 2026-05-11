# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       ForumPost Instance Methods                            #
# --------------------------------------------------------------------------- #

RSpec.describe ForumPost do
  let(:member)          { create(:user) }
  let(:janitor)         { create(:janitor_user) }
  let(:moderator)       { create(:moderator_user) }
  let(:admin)           { create(:admin_user) }
  let(:other)           { create(:user) }
  let(:category)        { create(:forum_category) }
  let(:admin_category)  { create(:forum_category, can_view: User::Levels::ADMIN) }
  let(:topic)           { CurrentUser.scoped(member) { create(:forum_topic, category_id: category.id) } }

  before do
    CurrentUser.user = member
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user = nil
    CurrentUser.ip_addr = nil
  end

  def make_post(overrides = {})
    create(:forum_post, topic_id: topic.id, **overrides)
  end

  # -------------------------------------------------------------------------
  # #can_access?
  # -------------------------------------------------------------------------
  describe "#can_access?" do
    it "returns false for blank users" do
      post = make_post
      expect(post.can_access?(nil)).to be false
    end

    it "is visible to a staff member even when hidden" do
      post = make_post
      post.update_columns(is_hidden: true)
      expect(post.can_access?(janitor)).to be true
    end

    it "is visible to a member when not hidden and in an accessible topic" do
      expect(make_post.can_access?(member)).to be true
    end

    it "is not visible to an unrelated member when hidden" do
      post = make_post
      post.update_columns(is_hidden: true)
      expect(post.can_access?(other)).to be false
    end

    it "is visible to the creator even when hidden" do
      post = make_post
      post.update_columns(is_hidden: true, creator_id: member.id)
      expect(post.can_access?(member)).to be true
    end

    it "is not visible to a member when the topic is hidden from them" do
      post = make_post
      topic.update_columns(is_hidden: true, creator_id: other.id)
      expect(post.reload.can_access?(member)).to be false
    end

    it "is not visible to a janitor when the topic is hidden from them" do
      post = make_post
      topic.update_columns(category_id: admin_category.id)
      expect(post.reload.can_access?(janitor)).to be false
    end

    it "is not visible if the topic is missing" do
      post = make_post
      # topic_id is readonly, so we have to stub it instead
      allow(post).to receive(:topic).and_return(nil)
      expect(post.can_access?(member)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #can_edit?
  # -------------------------------------------------------------------------
  describe "#can_edit?" do
    it "allows an admin to edit any post" do
      expect(make_post.can_edit?(admin)).to be true
    end

    it "allows the creator to edit their own visible, non-warned post" do
      post = make_post
      post.update_columns(creator_id: member.id)
      expect(post.can_edit?(member)).to be true
    end

    it "denies the creator when the post has a warning" do
      post = make_post
      post.update_columns(creator_id: member.id, warning_type: 1, warning_user_id: moderator.id)
      expect(post.can_edit?(member)).to be false
    end

    it "denies a non-creator non-admin" do
      post = make_post
      expect(post.can_edit?(other)).to be false
    end

    it "denies when the topic is hidden from the user" do
      post = make_post
      post.update_columns(creator_id: member.id)
      topic.update_columns(is_hidden: true, creator_id: other.id)
      expect(post.reload.can_edit?(member)).to be false
    end

    it "denies when the topic is locked" do
      post = make_post
      post.update_columns(creator_id: member.id)
      topic.update_columns(is_locked: true)
      expect(post.reload.can_edit?(member)).to be false
    end

    it "allows when the topic is locked but the user can lock" do
      post = make_post
      topic.update_columns(is_locked: true)
      expect(post.reload.can_edit?(admin)).to be true
    end
  end

  # -------------------------------------------------------------------------
  # #can_hide?
  # -------------------------------------------------------------------------
  describe "#can_hide?" do
    it "allows a moderator to hide any post" do
      expect(make_post.can_hide?(moderator)).to be true
    end

    it "allows the creator to hide their own non-warned post" do
      post = make_post
      post.update_columns(creator_id: member.id)
      expect(post.can_hide?(member)).to be true
    end

    it "denies the creator when the post has a warning" do
      post = make_post
      post.update_columns(creator_id: member.id, warning_type: 1, warning_user_id: moderator.id)
      expect(post.can_hide?(member)).to be false
    end

    it "denies an unrelated user" do
      expect(make_post.can_hide?(other)).to be false
    end

    it "denies when the topic is hidden from the user" do
      post = make_post
      post.update_columns(creator_id: member.id)
      topic.update_columns(is_hidden: true, creator_id: other.id)
      expect(post.reload.can_hide?(member)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #can_unhide?
  # -------------------------------------------------------------------------
  describe "#can_unhide?" do
    it "allows a moderator to unhide any post" do
      expect(make_post.can_unhide?(moderator)).to be true
    end

    it "does not allow regular members to unhide posts" do
      post = make_post
      post.update_columns(creator_id: member.id)
      expect(post.can_unhide?(member)).to be false
    end

    it "denies an unrelated user" do
      expect(make_post.can_unhide?(other)).to be false
    end

    it "denies when the topic is hidden from the user" do
      post = make_post
      post.update_columns(creator_id: member.id)
      topic.update_columns(creator_id: other.id, category_id: admin_category.id)
      expect(post.reload.can_unhide?(member)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #can_warn?
  # -------------------------------------------------------------------------
  describe "#can_warn?" do
    it "allows a moderator to warn a post" do
      expect(make_post.can_warn?(moderator)).to be true
    end

    it "denies a janitor" do
      expect(make_post.can_warn?(janitor)).to be false
    end

    it "denies a regular member" do
      expect(make_post.can_warn?(member)).to be false
    end

    it "denies when the topic is hidden from the user" do
      post = make_post
      post.update_columns(creator_id: member.id)
      topic.update_columns(creator_id: member.id, category_id: admin_category.id)
      expect(post.reload.can_warn?(moderator)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #can_vote?
  # -------------------------------------------------------------------------
  describe "#can_vote?" do
    it "allows a member to vote on a post" do
      expect(make_post.can_vote?(member)).to be true
    end

    it "allows a moderator to vote on a post" do
      expect(make_post.can_vote?(moderator)).to be true
    end

    it "denies when the topic is hidden from the user" do
      post = make_post
      topic.update_columns(is_hidden: true, creator_id: other.id)
      expect(post.reload.can_vote?(member)).to be false
    end

    it "denies anonymous users" do
      expect(make_post.can_vote?(nil)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #can_destroy?
  # -------------------------------------------------------------------------
  describe "#can_destroy?" do
    it "allows an admin to destroy a post" do
      expect(make_post.can_destroy?(admin)).to be true
    end

    it "denies a moderator" do
      expect(make_post.can_destroy?(moderator)).to be false
    end

    it "denies a regular member" do
      expect(make_post.can_destroy?(member)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #hide! / #unhide!
  # -------------------------------------------------------------------------
  describe "#hide!" do
    it "sets is_hidden to true" do
      post = make_post
      expect { post.hide! }.to change { post.reload.is_hidden }.from(false).to(true)
    end
  end

  describe "#unhide!" do
    it "sets is_hidden to false" do
      post = make_post
      post.update_columns(is_hidden: true)
      expect { post.unhide! }.to change { post.reload.is_hidden }.from(true).to(false)
    end
  end

  # -------------------------------------------------------------------------
  # #delete_topic_if_original_post
  # -------------------------------------------------------------------------
  describe "#delete_topic_if_original_post" do
    it "hides the parent topic when the original post is hidden" do
      original_post = topic.original_post
      expect { original_post.hide! }.to change { topic.reload.is_hidden }.from(false).to(true)
    end

    it "does not hide the topic when a non-original post is hidden" do
      make_post # original post already exists; this is a reply
      reply = make_post
      expect { reply.hide! }.not_to(change { topic.reload.is_hidden })
    end
  end

  # -------------------------------------------------------------------------
  # #is_original_post?
  # -------------------------------------------------------------------------
  describe "#is_original_post?" do
    it "returns true for the first post of a topic" do
      expect(topic.original_post.is_original_post?).to be true
    end

    it "returns false for a subsequent post in the same topic" do
      reply = make_post
      expect(reply.is_original_post?).to be false
    end

    it "accepts an explicit original_post_id and returns true when ids match" do
      original = topic.original_post
      expect(original.is_original_post?(original.id)).to be true
    end

    it "accepts an explicit original_post_id and returns false when ids differ" do
      reply = make_post
      expect(reply.is_original_post?(topic.original_post.id)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #forum_topic_page
  # -------------------------------------------------------------------------
  describe "#forum_topic_page" do
    it "returns 1 for a post on the first page" do
      expect(topic.original_post.forum_topic_page).to eq(1)
    end

    it "returns 2 for a post that falls on the second page" do
      per_page = Danbooru.config.records_per_page
      # Create enough posts to fill the first page, then one more.
      # travel_to guarantees last_post has a strictly later created_at so the
      # created_at <= ? count in forum_topic_page is deterministic even if earlier
      # posts share identical microsecond timestamps (common on fast machines / WSL2).
      per_page.times { make_post }
      last_post = travel_to(1.minute.from_now) { make_post }
      expect(last_post.forum_topic_page).to eq(2)
    end
  end

  # -------------------------------------------------------------------------
  # #votable?
  # -------------------------------------------------------------------------
  describe "#votable?" do
    it "returns false when no tag change request is associated" do
      expect(make_post.votable?).to be false
    end

    it "returns true when a tag alias is linked to the post" do
      post = make_post
      ta = create(:tag_alias)
      ta.update_columns(forum_post_id: post.id)
      expect(post.votable?).to be true
    end
  end

  # -------------------------------------------------------------------------
  # #tag_change_request
  # -------------------------------------------------------------------------
  describe "#tag_change_request" do
    it "returns nil when no association exists" do
      expect(make_post.tag_change_request).to be_nil
    end

    # TODO: BURs do not have a factory yet
    # it "returns the bulk_update_request when one is linked" do
    #   post = make_post
    #   bur = create(:bulk_update_request)
    #   bur.update_columns(forum_post_id: post.id)
    #   expect(post.tag_change_request).to eq(bur)
    # end

    it "returns the tag_alias when one is linked and no bulk_update_request exists" do
      post = make_post
      ta = create(:tag_alias)
      ta.update_columns(forum_post_id: post.id)
      post.reload
      expect(post.tag_change_request).to eq(ta)
    end
  end

  # -------------------------------------------------------------------------
  # Topic response_count callbacks
  # -------------------------------------------------------------------------
  describe "response_count" do
    it "increments topic response_count when a forum post is created" do
      expect { make_post }.to change { topic.reload.response_count }.by(1)
    end

    it "decrements topic response_count when a forum post is destroyed" do
      post = make_post
      expect { post.destroy! }.to change { topic.reload.response_count }.by(-1)
    end
  end
end
