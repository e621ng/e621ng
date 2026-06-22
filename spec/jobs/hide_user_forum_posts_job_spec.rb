# frozen_string_literal: true

require "rails_helper"

RSpec.describe HideUserForumPostsJob do
  include_context "as admin"

  let(:target_user) { create(:user) }
  let(:other_user)  { create(:user) }

  def perform(user_id = target_user.id)
    described_class.perform_now(user_id, CurrentUser.id)
  end

  describe "#perform" do
    context "when the user has created forum topics" do
      let!(:topic) { CurrentUser.scoped(target_user) { create(:forum_topic) } }

      it "hides the forum topic" do
        perform
        expect(topic.reload.is_hidden).to be(true)
      end

      it "does not increase the hidden topic count when topics are already hidden" do
        topic.update_columns(is_hidden: true)
        expect { perform }.not_to(change { ForumTopic.where(is_hidden: true).count })
      end
    end

    context "when the user has replied to another user's topic" do
      let!(:other_topic) { CurrentUser.scoped(other_user) { create(:forum_topic) } }
      let!(:reply) do
        CurrentUser.scoped(target_user) do
          create(:forum_post, topic_id: other_topic.id)
        end
      end

      it "hides the reply" do
        perform
        expect(reply.reload.is_hidden).to be(true)
      end
    end

    context "when the user has posts inside their own topic" do
      let!(:topic) { CurrentUser.scoped(target_user) { create(:forum_topic) } }

      it "does not try to hide the original post separately (topic hide covers it)" do
        post_in_own_topic = topic.original_post
        perform
        # The topic is hidden; the post's is_hidden state is irrelevant,
        # but crucially hide! is never called on it directly.
        expect(post_in_own_topic.reload.is_hidden).to be(false)
      end
    end

    context "when another user has forum content" do
      let!(:other_topic) { CurrentUser.scoped(other_user) { create(:forum_topic) } }
      let!(:other_reply) { CurrentUser.scoped(other_user) { create(:forum_post, topic_id: other_topic.id) } }

      it "does not hide the other user's topic" do
        perform
        expect(other_topic.reload.is_hidden).to be(false)
      end

      it "does not hide the other user's reply" do
        perform
        expect(other_reply.reload.is_hidden).to be(false)
      end
    end

    context "when the user does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect { perform(0) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
