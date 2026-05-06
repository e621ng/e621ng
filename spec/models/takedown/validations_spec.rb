# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          Takedown Validations                               #
# --------------------------------------------------------------------------- #

RSpec.describe Takedown do
  include_context "as admin"

  # Helper that builds a takedown without triggering the can_create_takedown
  # rate-limit (admin creators bypass that check).
  def make(overrides = {})
    build(:takedown, **overrides)
  end

  # -------------------------------------------------------------------------
  # email
  # -------------------------------------------------------------------------
  describe "email" do
    it "is invalid without an email" do
      record = make(email: nil)
      expect(record).not_to be_valid
      expect(record.errors[:email]).to be_present
    end

    it "is invalid with a blank email" do
      record = make(email: "")
      expect(record).not_to be_valid
      expect(record.errors[:email]).to be_present
    end

    it "is invalid with a malformed email (no @)" do
      record = make(email: "notanemail")
      expect(record).not_to be_valid
      expect(record.errors[:email]).to be_present
    end

    it "is invalid with a malformed email (no domain)" do
      record = make(email: "user@")
      expect(record).not_to be_valid
      expect(record.errors[:email]).to be_present
    end

    it "is valid with a well-formed email" do
      record = make(email: "user@example.com")
      expect(record).to be_valid
    end

    it "is invalid when exceeding 250 characters" do
      record = make(email: "#{'a' * 240}@example.com")
      expect(record).not_to be_valid
      expect(record.errors[:email]).to be_present
    end

    it "is valid at exactly 250 characters" do
      record = make(email: "#{'a' * 244}@b.com")
      expect(record.email.length).to eq(250)
      expect(record).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # reason
  # -------------------------------------------------------------------------
  describe "reason" do
    it "is invalid without a reason" do
      record = make(reason: nil)
      expect(record).not_to be_valid
      expect(record.errors[:reason]).to be_present
    end

    it "is invalid with a blank reason" do
      record = make(reason: "")
      expect(record).not_to be_valid
      expect(record.errors[:reason]).to be_present
    end

    it "is invalid when exceeding 5000 characters" do
      record = make(reason: "a" * 5001)
      expect(record).not_to be_valid
      expect(record.errors[:reason]).to be_present
    end

    it "is valid at exactly 5000 characters" do
      expect(make(reason: "a" * 5000)).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # instructions
  # -------------------------------------------------------------------------
  describe "instructions" do
    it "is invalid when exceeding 5000 characters" do
      record = make(instructions: "a" * 5001)
      expect(record).not_to be_valid
      expect(record.errors[:instructions]).to be_present
    end

    it "is valid at exactly 5000 characters" do
      expect(make(instructions: "a" * 5000)).to be_valid
    end

    it "is valid when blank (as long as post_ids are present)" do
      post = create(:post)
      record = build(:takedown_with_post, post: post, instructions: nil)
      expect(record).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # notes
  # -------------------------------------------------------------------------
  describe "notes" do
    it "is invalid when exceeding 5000 characters" do
      record = make(notes: "a" * 5001)
      expect(record).not_to be_valid
      expect(record.errors[:notes]).to be_present
    end

    it "is valid at exactly 5000 characters" do
      expect(make(notes: "a" * 5000)).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # valid_posts_or_instructions (on: :create)
  # -------------------------------------------------------------------------
  describe "valid_posts_or_instructions (on create)" do
    it "is invalid when post_ids is empty and instructions is blank" do
      record = make(post_ids: "", instructions: nil)
      expect(record).not_to be_valid
      expect(record.errors[:base]).to include("You must provide post ids or instructions.")
    end

    it "is valid when instructions is present and post_ids is empty" do
      record = make(post_ids: "", instructions: "Please remove my artwork.")
      expect(record).to be_valid
    end

    it "is valid when post_ids references a real post and instructions is blank" do
      post = create(:post)
      record = build(:takedown_with_post, post: post, instructions: nil)
      expect(record).to be_valid
    end

    it "does not re-run on update" do
      takedown = create(:takedown)
      # Wipe both fields — should only fail on create, not update
      takedown.update_columns(post_ids: "", instructions: nil)
      takedown.reload
      takedown.reason = "Updated reason"
      expect(takedown).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # can_create_takedown (on: :create)
  # -------------------------------------------------------------------------
  describe "can_create_takedown (on create)" do
    let(:admin) { create(:admin_user) }
    let(:member) { create(:user) }

    it "allows an admin creator regardless of any limits" do
      # Admin user set by include_context "as admin"; factory also creates as admin
      record = make
      expect(record).to be_valid
    end

    context "with a non-admin creator" do
      before do
        CurrentUser.user    = member
        CurrentUser.ip_addr = "104.20.31.112"
      end

      after do
        CurrentUser.user    = nil
        CurrentUser.ip_addr = nil
      end

      it "is invalid when the creator IP is banned" do
        IpBan.create!(ip_addr: "104.20.31.112", reason: "test ban", creator: admin)
        record = build(:takedown)
        expect(record).not_to be_valid
        expect(record.errors[:base]).to include(a_string_including("email us at"))
      end

      it "is invalid when the same IP has more than 5 takedowns in the past 24 hours" do
        # Create 6 existing takedowns for this IP using update_columns to bypass callbacks
        6.times do
          td = create(:takedown)
          td.update_columns(creator_ip_addr: "191.89.64.1", created_at: 1.hour.ago)
        end
        record = build(:takedown)
        expect(record).not_to be_valid
        expect(record.errors[:base]).to include(a_string_including("too many takedowns"))
      end

      it "is invalid when the same user has more than 5 takedowns in the past 24 hours" do
        6.times do
          td = create(:takedown)
          td.update_columns(creator_id: member.id, creator_ip_addr: "104.20.31.112", created_at: 1.hour.ago)
        end
        record = build(:takedown)
        expect(record).not_to be_valid
        expect(record.errors[:base]).to include(a_string_including("too many takedowns"))
      end

      it "is valid when the same IP has exactly 5 takedowns in the past 24 hours" do
        5.times do
          td = create(:takedown)
          td.update_columns(creator_ip_addr: "104.20.31.112", created_at: 1.hour.ago)
        end
        record = build(:takedown)
        expect(record).to be_valid
      end

      it "does not count takedowns older than 24 hours toward the limit" do
        6.times do
          td = create(:takedown)
          td.update_columns(creator_ip_addr: "104.20.31.112", created_at: 25.hours.ago)
        end
        record = build(:takedown)
        expect(record).to be_valid
      end
    end

    it "does not re-run on update" do
      takedown = create(:takedown)
      # Exhaust the rate limit for a different IP after creation
      6.times do
        td = create(:takedown)
        td.update_columns(creator_ip_addr: takedown.creator_ip_addr, created_at: 1.hour.ago)
      end
      # Updating the existing record should not trigger can_create_takedown
      takedown.reason = "Updated reason"
      expect(takedown).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # validate_number_of_posts
  # -------------------------------------------------------------------------
  describe "validate_number_of_posts" do
    it "is invalid when post_ids contains more than 5000 IDs" do
      takedown = create(:takedown)
      # Bypass callbacks/validations to set an oversized post_ids
      ids = (1..5001).to_a.join(" ")
      takedown.update_columns(post_ids: ids)
      takedown.reload
      # Trigger validation directly
      takedown.valid?
      expect(takedown.errors[:base]).to include("You can only have 5000 posts in a takedown.")
    end

    it "is valid with exactly 5000 post IDs" do
      takedown = create(:takedown)
      ids = (1..5000).to_a.join(" ")
      takedown.update_columns(post_ids: ids)
      takedown.reload
      takedown.valid?
      expect(takedown.errors[:base]).not_to include(a_string_including("5000"))
    end
  end

  # -------------------------------------------------------------------------
  # validate_post_ids
  # -------------------------------------------------------------------------
  describe "validate_post_ids" do
    it "removes post IDs that do not exist in the database" do
      fake_id = 999_999_999
      record = make(post_ids: fake_id.to_s, instructions: "fallback")
      record.valid?
      # After validation the non-existent ID is stripped
      expect(record.post_ids).to eq("")
    end

    it "keeps post IDs that do exist in the database" do
      post = create(:post)
      record = build(:takedown_with_post, post: post)
      record.valid?
      expect(record.post_ids).to include(post.id.to_s)
    end

    it "strips non-existent IDs while preserving real ones" do
      post = create(:post)
      fake_id = 999_999_998
      record = make(post_ids: "#{post.id} #{fake_id}", instructions: "fallback")
      record.valid?
      expect(record.post_array).to include(post.id)
      expect(record.post_array).not_to include(fake_id)
    end
  end
end
