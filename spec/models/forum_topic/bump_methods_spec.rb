# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         ForumTopic Bump Methods                             #
# --------------------------------------------------------------------------- #

RSpec.describe ForumTopic do
  let(:member) { create(:user) }

  before do
    CurrentUser.user = member
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user = nil
    CurrentUser.ip_addr = nil
  end

  def make_old_topic
    topic = create(:forum_topic)
    topic.update_columns(last_bumped_at: 1.day.ago)
    topic.reload
  end

  describe "last_bumped_at" do
    it "is set when the topic is created" do
      topic = create(:forum_topic)
      expect(topic.reload.last_bumped_at).to be_within(5.seconds).of(Time.current)
    end

    it "is updated when the topic is edited" do
      topic = make_old_topic
      topic.update!(title: "new title")
      expect(topic.reload.last_bumped_at).to be_within(5.seconds).of(Time.current)
    end

    it "is not updated when nothing changed" do
      topic = make_old_topic
      expect { topic.save! }.not_to(change { topic.reload.last_bumped_at })
    end

    it "is not updated when do_not_bump is true" do
      topic = make_old_topic
      expect { topic.update!(title: "new title", do_not_bump: true) }.not_to(change { topic.reload.last_bumped_at })
    end

    it "is not updated when do_not_bump is \"1\"" do
      topic = make_old_topic
      expect { topic.update!(title: "new title", do_not_bump: "1") }.not_to(change { topic.reload.last_bumped_at })
    end

    it "is updated when do_not_bump is \"0\"" do
      topic = make_old_topic
      expect { topic.update!(title: "new title", do_not_bump: "0") }.to(change { topic.reload.last_bumped_at })
    end
  end

  describe "replies" do
    it "bump the topic" do
      topic = make_old_topic
      create(:forum_post, topic_id: topic.id)
      expect(topic.reload.last_bumped_at).to be_within(5.seconds).of(Time.current)
    end

    it "do not bump the topic when do_not_bump_topic is true" do
      topic = make_old_topic
      expect { create(:forum_post, topic_id: topic.id, do_not_bump_topic: true) }.not_to(change { topic.reload.last_bumped_at })
    end

    it "do not bump the topic when do_not_bump_topic is \"1\"" do
      topic = make_old_topic
      expect { create(:forum_post, topic_id: topic.id, do_not_bump_topic: "1") }.not_to(change { topic.reload.last_bumped_at })
    end

    it "bump the topic when do_not_bump_topic is \"0\"" do
      topic = make_old_topic
      expect { create(:forum_post, topic_id: topic.id, do_not_bump_topic: "0") }.to(change { topic.reload.last_bumped_at })
    end

    it "still update updated_at and response_count when not bumping" do
      topic = make_old_topic
      topic.update_columns(updated_at: 1.day.ago)
      expect { create(:forum_post, topic_id: topic.id, do_not_bump_topic: true) }.to(change { topic.reload.response_count }.by(1).and(change { topic.reload.updated_at }))
    end
  end
end
