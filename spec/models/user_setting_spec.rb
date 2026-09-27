# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserSetting do
  let(:user) { create(:user) }

  describe "schema" do
    it "uses user_id as the primary key" do
      expect(described_class.primary_key).to eq("user_id")
    end

    it "defaults settings to an empty object" do
      setting = described_class.create!(user_id: user.id)
      expect(setting.settings).to eq({})
    end

    it "requires a valid user" do
      expect do
        described_class.create!(user_id: 0, settings: {})
      end.to raise_error(ActiveRecord::RecordInvalid, /User must exist/)
    end
  end

  describe ".valid_key?" do
    it "accepts an allowlisted key" do
      expect(described_class.valid_key?("posts_video_player")).to be(true)
    end

    it "rejects an unknown key" do
      expect(described_class.valid_key?("some_arbitrary_key")).to be(false)
    end
  end

  describe ".valid_value?" do
    it "accepts a string for a string setting" do
      expect(described_class.valid_value?("posts_video_player", "native")).to be(true)
    end

    it "rejects a non-string for a string setting" do
      expect(described_class.valid_value?("posts_video_player", 1)).to be(false)
    end

    it "accepts true/false for a boolean setting" do
      expect(described_class.valid_value?("site_events", true)).to be(true)
      expect(described_class.valid_value?("site_events", false)).to be(true)
    end

    it "rejects a string for a boolean setting (no coercion)" do
      expect(described_class.valid_value?("site_events", "false")).to be(false)
    end

    it "accepts an integer for an integer setting" do
      expect(described_class.valid_value?("posts_wiki_excerpt", 2)).to be(true)
    end

    it "rejects a numeric string for an integer setting (no coercion)" do
      expect(described_class.valid_value?("posts_wiki_excerpt", "2")).to be(false)
    end

    it "rejects any value for an unknown key" do
      expect(described_class.valid_value?("some_arbitrary_key", "anything")).to be(false)
    end
  end

  describe ".apply_changes!" do
    it "creates the settings row on first write and bumps the revision" do
      expect do
        described_class.apply_changes!(user, "posts_video_player" => "native")
      end.to change { user.reload.settings_revision }.by(1)

      expect(described_class.find(user.id).settings).to eq("posts_video_player" => "native")
    end

    it "merges into existing settings without dropping other keys" do
      described_class.apply_changes!(user, "posts_video_player" => "native")
      described_class.apply_changes!(user, "theme_gestures" => true)

      expect(described_class.find(user.id).settings).to eq(
        "posts_video_player" => "native",
        "theme_gestures" => true,
      )
    end

    it "overwrites an explicitly-chosen value even when it equals the app default" do
      described_class.apply_changes!(user, "posts_video_player" => "native")
      described_class.apply_changes!(user, "posts_video_player" => "custom")

      expect(described_class.find(user.id).settings["posts_video_player"]).to eq("custom")
    end

    it "returns the new revision and the full settings hash" do
      revision, settings = described_class.apply_changes!(user, "posts_video_player" => "native")
      expect(revision).to eq(user.reload.settings_revision)
      expect(settings).to eq("posts_video_player" => "native")
    end

    it "locks the user row before reading/writing settings, serializing concurrent writers" do
      # This is what makes two devices changing different keys at once (or the
      # very first write racing another) safe: real concurrency across DB
      # connections isn't exercisable under transactional fixtures, so this
      # pins down the locking primitive the safety actually relies on.
      allow(User).to receive(:lock).and_call_original
      described_class.apply_changes!(user, "posts_video_player" => "native")
      expect(User).to have_received(:lock)
    end

    context "with an empty changes hash" do
      it "does not create a settings row" do
        described_class.apply_changes!(user, {})
        expect(described_class.find_by(user_id: user.id)).to be_nil
      end

      it "does not bump the revision" do
        expect do
          described_class.apply_changes!(user, {})
        end.not_to(change { user.reload.settings_revision })
      end

      it "returns the current (unchanged) revision and settings" do
        described_class.apply_changes!(user, "posts_video_player" => "native")
        user.reload

        revision, settings = described_class.apply_changes!(user, {})

        expect(revision).to eq(user.settings_revision)
        expect(settings).to eq("posts_video_player" => "native")
      end
    end
  end
end
