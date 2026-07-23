# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       User upload karma / levels                            #
# --------------------------------------------------------------------------- #

RSpec.describe User do
  let(:user) { create(:user) }

  before do
    allow(Danbooru.config.custom_configuration).to receive_messages(
      upload_karma_l1_threshold: 100,
      upload_karma_l10_threshold: 10_000,
      upload_karma_free_threshold: 1,
    )
  end

  def set_karma(target, value)
    target.user_status.update_columns(upload_karma: value)
    target.reload
  end

  # -------------------------------------------------------------------------
  # #raw_upload_karma
  # -------------------------------------------------------------------------
  describe "#raw_upload_karma" do
    it "defaults to 0 for a new user" do
      expect(user.raw_upload_karma).to eq(0)
    end

    it "returns the raw stored value, including negatives" do
      set_karma(user, -7)
      expect(user.raw_upload_karma).to eq(-7)
    end
  end

  # -------------------------------------------------------------------------
  # #upload_karma
  # -------------------------------------------------------------------------
  describe "#upload_karma" do
    it "returns the raw value when positive" do
      set_karma(user, 42)
      expect(user.upload_karma).to eq(42)
    end

    it "clamps negative karma to 0 for display" do
      set_karma(user, -7)
      expect(user.upload_karma).to eq(0)
    end
  end

  # -------------------------------------------------------------------------
  # #upload_karma_level
  # -------------------------------------------------------------------------
  describe "#upload_karma_level" do
    it "returns 0 for a new user" do
      expect(user.upload_karma_level).to eq(0)
    end

    it "returns the level based on the raw value" do
      set_karma(user, 0)
      expect(user.upload_karma_level).to eq(0)

      set_karma(user, Danbooru.config.upload_karma_l1_threshold)
      expect(user.upload_karma_level).to eq(1)

      set_karma(user, Danbooru.config.upload_karma_l10_threshold)
      expect(user.upload_karma_level).to eq(10)
    end

    it "returns 0 for negative karma" do
      set_karma(user, -7)
      expect(user.upload_karma_level).to eq(0)
    end
  end

  # -------------------------------------------------------------------------
  # #required_karma_for_level
  # -------------------------------------------------------------------------
  describe "#required_karma_for_level" do
    it "returns the required karma for a given level" do
      expect(user.required_karma_for_level(-1)).to eq(0)
      expect(user.required_karma_for_level(0)).to eq(0)
      expect(user.required_karma_for_level(1)).to eq(Danbooru.config.upload_karma_l1_threshold)
      expect(user.required_karma_for_level(10)).to eq(Danbooru.config.upload_karma_l10_threshold)
    end
  end

  # -------------------------------------------------------------------------
  # #upload_karma_percent
  # -------------------------------------------------------------------------
  describe "#upload_karma_percent" do
    it "returns the percentage of progress toward the next level" do
      required_for_level_one = user.required_karma_for_level(1)
      required_for_level_two = user.required_karma_for_level(2)

      set_karma(user, 0)
      expect(user.upload_karma_percent).to eq(0)

      set_karma(user, required_for_level_one / 2)
      expect(user.upload_karma_percent).to eq(50)

      set_karma(user, required_for_level_one - 1)
      expect(user.upload_karma_percent).to eq(99)

      set_karma(user, required_for_level_one + ((required_for_level_two - required_for_level_one) / 2))
      expect(user.upload_karma_percent).to eq(49)

      set_karma(user, required_for_level_two - 1)
      expect(user.upload_karma_percent).to eq(99)
    end

    it "returns 0 for negative karma" do
      set_karma(user, -7)
      expect(user.upload_karma_percent).to eq(0)
    end
  end

  # -------------------------------------------------------------------------
  # #upload_karma_free?
  # -------------------------------------------------------------------------
  describe "#upload_karma_free?" do
    let(:upload_free_karma_threshold) { user.required_karma_for_level(Danbooru.config.upload_karma_free_threshold) }

    it "is false below the threshold" do
      set_karma(user, upload_free_karma_threshold - 1)
      expect(user.upload_karma_free?).to be false
    end

    it "is true at or above the threshold" do
      set_karma(user, upload_free_karma_threshold)
      expect(user.upload_karma_free?).to be true
    end

    it "returns false when the threshold is nil" do
      allow(Danbooru.config.custom_configuration).to receive(:upload_karma_free_threshold).and_return(nil)
      set_karma(user, Danbooru.config.upload_karma_l10_threshold)
      expect(user.upload_karma_free?).to be false
    end

    it "returns false when the user has disabled unlimited uploads" do
      set_karma(user, upload_free_karma_threshold + 1000)
      user.no_karma_free = true
      expect(user.upload_karma_free?).to be false
    end
  end
end
