# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserNameChangeRequest do
  include_context "as member"

  # Helper: build a request for the current member without touching the DB.
  # skip_user_name_validation: true lets us test other validations in isolation.
  def build_request(overrides = {})
    build(:user_name_change_request, user: CurrentUser.user, original_name: CurrentUser.user.name, **overrides)
  end

  # ------------------------------------------------------------------ #
  # Presence                                                            #
  # ------------------------------------------------------------------ #
  describe "presence validations" do
    it "is valid without original_name" do
      record = build_request(original_name: nil, skip_user_name_validation: true)
      expect(record).to be_valid
    end

    it "is invalid without desired_name" do
      record = build_request(desired_name: nil, skip_user_name_validation: true)
      expect(record).not_to be_valid
      expect(record.errors[:desired_name]).to be_present
    end
  end

  # ------------------------------------------------------------------ #
  # desired_name — UserNameValidator (via user_id lambda)              #
  # ------------------------------------------------------------------ #
  describe "desired_name name validation" do
    it "is invalid when desired_name is too short (< 2 characters)" do
      record = build_request(desired_name: "a")
      expect(record).not_to be_valid
      expect(record.errors[:desired_name]).to include("must be 2 to 20 characters long")
    end

    it "is invalid when desired_name is too long (> 20 characters)" do
      record = build_request(desired_name: "a" * 21)
      expect(record).not_to be_valid
      expect(record.errors[:desired_name]).to include("must be 2 to 20 characters long")
    end

    it "is invalid when desired_name contains disallowed characters" do
      record = build_request(desired_name: "bad name!")
      expect(record).not_to be_valid
      expect(record.errors[:desired_name]).to include("must contain only alphanumeric characters, hyphens, apostrophes, tildes and underscores")
    end

    it "is invalid when desired_name begins with a special character" do
      record = build_request(desired_name: "_leading")
      expect(record).not_to be_valid
      expect(record.errors[:desired_name]).to be_present
    end

    it "is invalid when desired_name contains consecutive special characters" do
      record = build_request(desired_name: "double__under")
      expect(record).not_to be_valid
      expect(record.errors[:desired_name]).to include("must not contain consecutive special characters")
    end

    it "is invalid when desired_name consists entirely of numbers" do
      record = build_request(desired_name: "12345")
      expect(record).not_to be_valid
      expect(record.errors[:desired_name]).to include("cannot consist of numbers only")
    end

    it "is invalid when desired_name is a reserved word" do
      %w[me home settings].each do |reserved|
        record = build_request(desired_name: reserved)
        expect(record).not_to be_valid
        expect(record.errors[:desired_name]).to include("cannot be one of the reserved words")
      end
    end

    it "is invalid when desired_name is already taken by another user" do
      other = create(:user, name: "taken_name")
      record = build_request(desired_name: other.name)
      expect(record).not_to be_valid
      expect(record.errors[:desired_name]).to include("already exists")
    end

    it "is invalid when desired_name is identical to the user's current name" do
      record = build_request(desired_name: CurrentUser.user.name)
      expect(record).not_to be_valid
      expect(record.errors[:desired_name]).to include("is the same as your current name")
    end

    it "is valid with a fresh, well-formed desired_name" do
      record = build_request(desired_name: "fresh_name")
      expect(record).to be_valid
    end

    it "skips desired_name validation when skip_user_name_validation is true" do
      record = build_request(desired_name: "!!!", skip_user_name_validation: true)
      # Only presence and not_limited run; desired_name errors should be absent
      record.valid?
      expect(record.errors[:desired_name]).to be_empty
    end
  end

  # ------------------------------------------------------------------ #
  # not_limited — 1 name change per user per week                      #
  # ------------------------------------------------------------------ #
  describe "not_limited validation" do
    it "is valid for a user's first request this week" do
      record = build_request(desired_name: "fresh_name", skip_limited_validation: false)
      expect(record).to be_valid
    end

    it "is invalid when the same user already submitted a request within the past week" do
      create(:user_name_change_request, user: CurrentUser.user,
                                        original_name: CurrentUser.user.name, desired_name: "first_change",
                                        skip_limited_validation: true)
      record = build_request(desired_name: "second_change", skip_limited_validation: false)
      expect(record).not_to be_valid
      expect(record.errors[:base]).to include("You can only submit one name change request per week")
    end

    it "does not enforce the limit when skip_limited_validation is true" do
      create(:user_name_change_request, user: CurrentUser.user,
                                        original_name: CurrentUser.user.name, desired_name: "first_change",
                                        skip_limited_validation: true)
      record = build_request(desired_name: "second_change", skip_limited_validation: true)
      expect(record).to be_valid
    end

    it "does not count requests from a different user toward the limit" do
      other_user = create(:user)
      create(:user_name_change_request, user: other_user,
                                        original_name: other_user.name, desired_name: "other_change",
                                        skip_limited_validation: true)
      record = build_request(desired_name: "my_change", skip_limited_validation: false)
      expect(record).to be_valid
    end
  end
end
