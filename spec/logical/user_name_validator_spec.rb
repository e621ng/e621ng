# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         UserNameValidator                                   #
# --------------------------------------------------------------------------- #
#
# Tests every rule enforced by UserNameValidator#validate_each.
# The validator is used by User (on :name, on: :create) and
# UserNameChangeRequest (on :desired_name).
#
# Tests run against a real User record via FactoryBot because the uniqueness
# branch calls User.find_by_name directly, making a dummy model impractical.

RSpec.describe UserNameValidator, type: :model do
  describe "uniqueness" do
    it "is invalid with a duplicate name" do
      existing_user = create(:user)
      new_user = build(:user, name: existing_user.name)
      expect(new_user).not_to be_valid
      expect(new_user.errors[:name]).to include("already exists")

      normal_user = build(:user)
      expect(normal_user).to be_valid
      normal_user.name = existing_user.name
      expect(normal_user).not_to be_valid
      expect(normal_user.errors[:name]).to include("already exists")
    end
  end

  describe "length" do
    it "is invalid when shorter than 2 characters" do
      user = build(:user, name: "a")
      expect(user).not_to be_valid
      expect(user.errors[:name]).to include("must be 2 to 20 characters long")
    end

    it "is invalid when longer than 20 characters" do
      user = build(:user, name: "a" * 21)
      expect(user).not_to be_valid
      expect(user.errors[:name]).to include("must be 2 to 20 characters long")
    end
  end

  describe "character set" do
    it "is invalid with disallowed characters" do
      user = build(:user, name: "bad name!")
      expect(user).not_to be_valid
      expect(user.errors[:name]).to include("must contain only alphanumeric characters, hyphens, apostrophes, tildes and underscores")
    end

    it "is valid with each allowed special character" do
      %w[good-name good'name good~name good_name].each do |name|
        user = build(:user, name: name)
        expect(user).to be_valid, "expected '#{name}' to be valid: #{user.errors.full_messages.join(', ')}"
      end
    end
  end

  describe "leading special character" do
    it "is invalid when starting with a special character" do
      %w[-name ~name 'name].each do |name|
        user = build(:user, name: name)
        expect(user).not_to be_valid
        expect(user.errors[:name]).to include("must not begin with a special character"), "expected '#{name}' to be invalid"
      end
    end
  end

  describe "consecutive special characters" do
    it "is invalid with consecutive special characters" do
      %w[na__me na--me na~~me na''me].each do |name|
        user = build(:user, name: name)
        expect(user).not_to be_valid
        expect(user.errors[:name]).to include("must not contain consecutive special characters"), "expected '#{name}' to be invalid"
      end
    end
  end

  describe "underscore boundaries" do
    it "is invalid when beginning or ending with an underscore" do
      %w[_name name_].each do |name|
        user = build(:user, name: name)
        expect(user).not_to be_valid
        expect(user.errors[:name]).to include("cannot begin or end with an underscore"), "expected '#{name}' to be invalid"
      end
    end
  end

  describe "numbers only" do
    it "is invalid when consisting of numbers only" do
      user = build(:user, name: "12345")
      expect(user).not_to be_valid
      expect(user.errors[:name]).to include("cannot consist of numbers only")
    end
  end

  describe "reserved words" do
    it "is invalid with reserved words" do
      %w[me home settings].each do |name|
        user = build(:user, name: name)
        expect(user).not_to be_valid
        expect(user.errors[:name]).to include("cannot be one of the reserved words"), "expected '#{name}' to be invalid"
      end
    end
  end

  describe "on: :create only" do
    it "does not revalidate name format on update" do
      user = create(:user)
      # Numbers-only name would fail on create but is skipped on update
      # because the validator is declared with `on: :create` in User.
      user.comment_threshold = 0
      expect(user).to be_valid
    end
  end
end
