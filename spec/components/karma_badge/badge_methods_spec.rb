# frozen_string_literal: true

require "rails_helper"

RSpec.describe KarmaBadge do
  include_context "as member"

  let(:user) { create(:user) }

  before do
    allow(Danbooru.config.custom_configuration).to receive_messages(
      upload_karma_l1_threshold: 100,
      upload_karma_l10_threshold: 10_000,
    )
  end

  def component(user = self.user)
    described_class.new(user: user)
  end

  def set_karma(target, value)
    target.user_status.update_columns(upload_karma: value)
    target.reload
  end

  describe "#karma_level" do
    it "returns the numeric level below the maximum" do
      set_karma(user, Danbooru.config.upload_karma_l1_threshold)
      expect(component.send(:karma_level)).to eq(1)
    end

    it "returns S at the maximum level" do
      set_karma(user, Danbooru.config.upload_karma_l10_threshold)
      expect(component.send(:karma_level)).to eq("S")
    end
  end

  describe "#badge_title" do
    it "shows progress toward the next level below the maximum" do
      set_karma(user, Danbooru.config.upload_karma_l1_threshold)
      required_for_next = user.required_karma_for_level(2)
      expect(component.send(:badge_title)).to eq("Upload Karma: #{user.upload_karma} / #{required_for_next} (Level 1)")
    end

    it "shows the S level at the maximum" do
      set_karma(user, Danbooru.config.upload_karma_l10_threshold)
      expect(component.send(:badge_title)).to eq("Upload Karma: #{user.upload_karma} (Level S)")
    end
  end

  describe "#progress_degree" do
    it "converts the karma percentage into degrees" do
      set_karma(user, Danbooru.config.upload_karma_l1_threshold / 2)
      expect(user.upload_karma_percent).to eq(50)
      expect(component.send(:progress_degree)).to eq(180)
    end

    it "returns 0 at the start of a level" do
      set_karma(user, Danbooru.config.upload_karma_l1_threshold)
      expect(component.send(:progress_degree)).to eq(0)
    end

    it "returns 0 at the maximum level" do
      set_karma(user, Danbooru.config.upload_karma_l10_threshold)
      expect(component.send(:progress_degree)).to eq(0)
    end
  end

  describe "#progress_degree_style" do
    it "embeds the progress degree in a conic gradient" do
      set_karma(user, Danbooru.config.upload_karma_l1_threshold / 2)
      expect(component.send(:progress_degree_style)).to eq(
        "background: conic-gradient(var(--color-button-active) 180deg, var(--color-section) 0deg);",
      )
    end
  end
end
