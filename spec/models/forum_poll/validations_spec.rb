# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                            ForumPoll Validations                            #
# --------------------------------------------------------------------------- #

RSpec.describe ForumPoll do
  include_context "as privileged"

  describe "options" do
    it "requires at least one option" do
      poll = build(:forum_poll, options_count: 0)
      expect(poll).not_to be_valid
      expect(poll.errors[:base]).to include("Poll needs at least one option")
    end

    it "allows a single option" do
      expect(build(:forum_poll, options_count: 1)).to be_valid
    end

    it "caps the option count at forum_poll_max_options" do
      allow(Danbooru.config.custom_configuration).to receive(:forum_poll_max_options).and_return(3)
      expect(build(:forum_poll, options_count: 3)).to be_valid
      poll = build(:forum_poll, options_count: 4)
      expect(poll).not_to be_valid
      expect(poll.errors[:base]).to include("Poll cannot have more than 3 options")
    end

    it "rejects blank option bodies" do
      poll = build(:forum_poll, options_count: 0)
      poll.options.build(body: "   ")
      expect(poll).not_to be_valid
      expect(poll.errors.full_messages).to include("Option can't be blank")
    end

    it "caps the option body length" do
      allow(Danbooru.config.custom_configuration).to receive(:forum_poll_option_max_size).and_return(5)
      poll = build(:forum_poll, options_count: 0)
      poll.options.build(body: "123456")
      expect(poll).not_to be_valid
    end

    it "rejects duplicates ignoring case and whitespace" do
      poll = build(:forum_poll, options_count: 0)
      poll.options.build(body: "Red  Fox")
      poll.options.build(body: " red fox ")
      expect(poll).not_to be_valid
      expect(poll.errors[:base]).to include("Poll options must be unique")
    end

    it "ignores options marked for destruction" do
      poll = create(:forum_poll, options_count: 2)
      poll.assign_attributes(options_attributes: [{ id: poll.options.first.id, _destroy: "1" }])
      expect(poll).to be_valid
      poll.save!
      expect(poll.options.reload.map(&:position)).to eq([0])
    end
  end

  describe "max_choices" do
    it "must be at least 1" do
      expect(build(:forum_poll, max_choices: 0)).not_to be_valid
    end

    it "cannot exceed the option count" do
      poll = build(:forum_poll, options_count: 2, max_choices: 3)
      expect(poll).not_to be_valid
      expect(poll.errors[:base]).to include("Max choices cannot exceed the number of options")
    end

    it "may equal the option count" do
      expect(build(:forum_poll, options_count: 2, max_choices: 2)).to be_valid
    end
  end

  describe "duration" do
    it "accepts every preset" do
      ForumPoll.durations.each_key do |key|
        expect(build(:forum_poll, duration: key)).to be_valid
      end
    end

    it "rejects unknown presets" do
      poll = build(:forum_poll, duration: "99y")
      expect(poll).not_to be_valid
      expect(poll.errors[:base]).to include("Duration is not one of the allowed presets")
    end

    it "rejects a missing duration" do
      expect(build(:forum_poll, duration: nil)).not_to be_valid
    end

    it "derives expires_at from the preset" do
      travel_to(Time.zone.parse("2026-11-10 12:00:00")) do
        poll = create(:forum_poll, duration: "3d")
        expect(poll.expires_at).to eq(3.days.from_now)
      end
    end
  end

  describe "creator" do
    it "rejects users below forum_poll_min_level" do
      CurrentUser.user = create(:user)
      poll = build(:forum_poll)
      expect(poll).not_to be_valid
      expect(poll.errors[:base]).to include("You are not allowed to create polls")
    end

    it "honours a lowered forum_poll_min_level" do
      allow(Danbooru.config.custom_configuration).to receive(:forum_poll_min_level).and_return(UserLevel::MEMBER)
      CurrentUser.user = create(:user)
      expect(build(:forum_poll)).to be_valid
    end

    it "enforces the daily creation limit" do
      allow(Danbooru.config.custom_configuration).to receive(:forum_poll_limit).and_return(1)
      create(:forum_poll)
      poll = build(:forum_poll)
      expect(poll).not_to be_valid
      expect(poll.errors[:base]).to include("You reached the daily limit for this action")
    end

    it "exempts staff from the creation limit" do
      allow(Danbooru.config.custom_configuration).to receive(:forum_poll_limit).and_return(1)
      CurrentUser.user = create(:moderator_user)
      create(:forum_poll)
      expect(build(:forum_poll)).to be_valid
    end
  end
end
