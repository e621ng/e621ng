# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       ForumTopic Audit Logging                              #
# --------------------------------------------------------------------------- #

RSpec.describe ForumTopic do
  include_context "as moderator"

  let(:category) { create(:forum_category) }

  def make_topic(overrides = {})
    create(:forum_topic, category_id: category.id, **overrides)
  end

  # -------------------------------------------------------------------------
  # Delete (before_destroy)
  # -------------------------------------------------------------------------
  describe "#create_mod_action_for_delete" do
    it "logs forum_topic_delete when the topic is destroyed" do
      topic = make_topic
      topic_id    = topic.id
      topic_title = topic.title

      topic.destroy!

      log = ModAction.where(action: "forum_topic_delete").last
      expect(log).not_to be_nil
      expect(log[:values]).to include("forum_topic_id" => topic_id, "forum_topic_title" => topic_title)
    end
  end

  # -------------------------------------------------------------------------
  # Lock / Unlock (after_save on is_locked change)
  # -------------------------------------------------------------------------
  describe "lock/unlock logging" do
    it "logs forum_topic_lock when is_locked changes to true" do
      topic = make_topic
      expect { topic.update!(is_locked: true) }.to change(ModAction, :count).by(1)
      expect(ModAction.last.action).to eq("forum_topic_lock")
    end

    it "logs forum_topic_unlock when is_locked changes to false" do
      topic = make_topic
      topic.update_columns(is_locked: true)
      expect { topic.update!(is_locked: false) }.to change(ModAction, :count).by(1)
      expect(ModAction.last.action).to eq("forum_topic_unlock")
    end

    it "does not log a lock action on plain topic creation" do
      # is_locked starts nil/false — no change fires; only creation callbacks run
      expect { make_topic }.not_to(change { ModAction.where(action: %w[forum_topic_lock forum_topic_unlock]).count })
    end

    it "records the topic id and title in the log values" do
      topic = make_topic
      topic.update!(is_locked: true)
      log = ModAction.last
      expect(log[:values]).to include("forum_topic_id" => topic.id, "forum_topic_title" => topic.title)
    end
  end

  # -------------------------------------------------------------------------
  # Stick / Unstick (after_save on is_sticky change)
  # -------------------------------------------------------------------------
  describe "stick/unstick logging" do
    it "logs forum_topic_stick when is_sticky changes to true" do
      topic = make_topic
      expect { topic.update!(is_sticky: true) }.to change(ModAction, :count).by(1)
      expect(ModAction.last.action).to eq("forum_topic_stick")
    end

    it "logs forum_topic_unstick when is_sticky changes to false" do
      topic = make_topic
      topic.update_columns(is_sticky: true)
      expect { topic.update!(is_sticky: false) }.to change(ModAction, :count).by(1)
      expect(ModAction.last.action).to eq("forum_topic_unstick")
    end

    it "records the topic id and title in the log values" do
      topic = make_topic
      topic.update!(is_sticky: true)
      log = ModAction.last
      expect(log[:values]).to include("forum_topic_id" => topic.id, "forum_topic_title" => topic.title)
    end
  end

  # -------------------------------------------------------------------------
  # Hide / Unhide (manual method calls)
  # -------------------------------------------------------------------------
  describe "#create_mod_action_for_hide" do
    it "logs forum_topic_hide" do
      topic = make_topic
      expect { topic.create_mod_action_for_hide }.to change(ModAction, :count).by(1)
      expect(ModAction.last.action).to eq("forum_topic_hide")
      expect(ModAction.last[:values]).to include("forum_topic_id" => topic.id, "forum_topic_title" => topic.title)
    end
  end

  describe "#create_mod_action_for_unhide" do
    it "logs forum_topic_unhide" do
      topic = make_topic
      expect { topic.create_mod_action_for_unhide }.to change(ModAction, :count).by(1)
      expect(ModAction.last.action).to eq("forum_topic_unhide")
      expect(ModAction.last[:values]).to include("forum_topic_id" => topic.id, "forum_topic_title" => topic.title)
    end
  end
end
