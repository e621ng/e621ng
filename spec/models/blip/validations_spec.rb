# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           Blip Validations                                  #
# --------------------------------------------------------------------------- #

RSpec.describe Blip do
  # -------------------------------------------------------------------------
  # body — presence
  # -------------------------------------------------------------------------
  describe "body — presence" do
    include_context "as member"

    it "is invalid with an empty body" do
      blip = build(:blip, body: "")
      expect(blip).not_to be_valid
      expect(blip.errors[:body]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # body — length
  # -------------------------------------------------------------------------
  describe "body — length" do
    include_context "as member"

    it "is invalid when body is shorter than 5 characters" do
      blip = build(:blip, body: "hi")
      expect(blip).not_to be_valid
      expect(blip.errors[:body]).to be_present
    end

    it "is valid when body is exactly 5 characters" do
      blip = build(:blip, body: "hello")
      expect(blip).to be_valid, blip.errors.full_messages.join(", ")
    end

    it "is invalid when body exceeds 1000 characters" do
      blip = build(:blip, body: "a" * 1001)
      expect(blip).not_to be_valid
      expect(blip.errors[:body]).to be_present
    end

    it "is valid when body is exactly 1000 characters" do
      blip = build(:blip, body: "a" * 1000)
      expect(blip).to be_valid, blip.errors.full_messages.join(", ")
    end
  end

  # -------------------------------------------------------------------------
  # validate_parent_exists — on: :create only
  # -------------------------------------------------------------------------
  describe "parent existence — validate_parent_exists" do
    include_context "as member"

    it "is invalid on create when response_to references a nonexistent blip" do
      blip = build(:blip, response_to: 99_999_999)
      expect(blip).not_to be_valid
      expect(blip.errors[:response_to]).to be_present
    end

    it "is valid on create when response_to references an existing blip" do
      parent = create(:blip)
      blip = build(:blip, response_to: parent.id)
      expect(blip).to be_valid, blip.errors.full_messages.join(", ")
    end

    it "is valid when response_to is absent" do
      blip = build(:blip, response_to: nil)
      expect(blip).to be_valid, blip.errors.full_messages.join(", ")
    end

    it "does not re-validate parent existence on update" do
      parent = create(:blip)
      blip = create(:blip, response_to: parent.id)
      parent.destroy!
      blip.body = "updated body content"
      expect(blip).to be_valid, blip.errors.full_messages.join(", ")
    end
  end

  # -------------------------------------------------------------------------
  # validate_creator_is_not_limited — happy path
  # -------------------------------------------------------------------------
  describe "creator throttle — validate_creator_is_not_limited" do
    include_context "as member"

    it "is valid when the creator is not throttled" do
      blip = build(:blip)
      expect(blip).to be_valid, blip.errors.full_messages.join(", ")
    end
  end
end
