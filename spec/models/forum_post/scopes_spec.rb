# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           ForumPost Scopes                                  #
# --------------------------------------------------------------------------- #

RSpec.describe ForumPost do
  let(:member)    { create(:user) }
  let(:other)     { create(:user) }
  let(:moderator) { create(:moderator_user) }
  let(:category)  { create(:forum_category) }
  let(:topic)     { CurrentUser.scoped(member) { create(:forum_topic, category_id: category.id) } }

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
  # .active
  # -------------------------------------------------------------------------
  describe ".active" do
    it "returns non-hidden posts to any user" do
      post = make_post
      expect(ForumPost.active(other)).to include(post)
    end

    it "returns a member's own hidden post to that member" do
      post = make_post
      post.update_columns(is_hidden: true, creator_id: member.id)
      expect(ForumPost.active(member)).to include(post)
    end

    it "excludes another user's hidden post from a regular member" do
      post = make_post
      post.update_columns(is_hidden: true, creator_id: other.id)
      expect(ForumPost.active(member)).not_to include(post)
    end

    it "returns all posts (including hidden) to a moderator" do
      post = make_post
      post.update_columns(is_hidden: true)
      expect(ForumPost.active(moderator)).to include(post)
    end
  end

  # -------------------------------------------------------------------------
  # .permitted
  # -------------------------------------------------------------------------
  describe ".permitted" do
    let(:restricted_category) { create(:forum_category, can_view: User::Levels::MODERATOR) }
    let(:restricted_topic) do
      CurrentUser.scoped(moderator) { create(:forum_topic, category_id: restricted_category.id) }
    end

    it "returns posts in categories the user can view" do
      post = make_post
      expect(ForumPost.permitted(member)).to include(post)
    end

    it "excludes posts in categories above the user's level" do
      post = CurrentUser.scoped(moderator) { create(:forum_post, topic_id: restricted_topic.id) }
      expect(ForumPost.permitted(member)).not_to include(post)
    end

    it "includes posts in restricted categories for a moderator" do
      post = CurrentUser.scoped(moderator) { create(:forum_post, topic_id: restricted_topic.id) }
      expect(ForumPost.permitted(moderator)).to include(post)
    end

    it "excludes posts in hidden topics from unrelated members" do
      post = make_post
      topic.update_columns(is_hidden: true, creator_id: other.id)
      expect(ForumPost.permitted(member)).not_to include(post)
    end

    it "includes posts in hidden topics for the topic creator" do
      post = make_post
      topic.update_columns(is_hidden: true, creator_id: member.id)
      expect(ForumPost.permitted(member)).to include(post)
    end

    it "includes posts in hidden topics for a moderator" do
      post = make_post
      topic.update_columns(is_hidden: true)
      expect(ForumPost.permitted(moderator)).to include(post)
    end
  end

  # -------------------------------------------------------------------------
  # .visible
  # -------------------------------------------------------------------------
  describe ".visible" do
    it "returns a non-hidden post in an accessible topic to a member" do
      post = make_post
      expect(ForumPost.visible(member)).to include(post)
    end

    it "excludes a hidden post from an unrelated member" do
      post = make_post
      post.update_columns(is_hidden: true, creator_id: other.id)
      expect(ForumPost.visible(member)).not_to include(post)
    end

    it "returns a member's own hidden post to that member" do
      post = make_post
      post.update_columns(is_hidden: true, creator_id: member.id)
      expect(ForumPost.visible(member)).to include(post)
    end

    it "returns all posts to a moderator" do
      post = make_post
      post.update_columns(is_hidden: true)
      expect(ForumPost.visible(moderator)).to include(post)
    end
  end

  # -------------------------------------------------------------------------
  # .for_user
  # -------------------------------------------------------------------------
  describe ".for_user" do
    it "returns only posts created by the specified user" do
      post_by_member = make_post
      post_by_member.update_columns(creator_id: member.id)
      post_by_other = make_post
      post_by_other.update_columns(creator_id: other.id)

      result = ForumPost.for_user(member.id)
      expect(result).to include(post_by_member)
      expect(result).not_to include(post_by_other)
    end
  end
end
