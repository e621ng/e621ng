# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                   PostSetMaintainer Validations                             #
# --------------------------------------------------------------------------- #
# All validations are on: :create only.

RSpec.describe PostSetMaintainer do
  include_context "as member"

  let(:owner)   { CurrentUser.user }
  let(:invitee) { create(:user) }
  let(:set)     { create(:public_post_set, creator: owner) }

  # -------------------------------------------------------------------------
  # ensure_not_set_owner
  # -------------------------------------------------------------------------
  describe "ensure_not_set_owner" do
    it "is invalid when the invited user is the set owner" do
      record = build(:post_set_maintainer, post_set: set, user: owner)
      expect(record).not_to be_valid
      expect(record.errors[:user]).to be_present
    end

    it "is valid when the invited user is different from the owner" do
      record = build(:post_set_maintainer, post_set: set, user: invitee)
      expect(record).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # ensure_set_public
  # -------------------------------------------------------------------------
  describe "ensure_set_public" do
    it "is invalid when the post set is private" do
      private_set = create(:post_set, is_public: false, creator: owner)
      record = build(:post_set_maintainer, post_set: private_set, user: invitee)
      expect(record).not_to be_valid
      expect(record.errors[:post_set]).to be_present
    end

    it "is valid when the post set is public" do
      record = build(:post_set_maintainer, post_set: set, user: invitee)
      expect(record).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # ensure_maintainer_count
  # -------------------------------------------------------------------------
  describe "ensure_maintainer_count" do
    it "is invalid when the set already has 75 maintainers" do
      users = create_list(:user, 75)
      PostSetMaintainer.insert_all(
        users.map do |u|
          { post_set_id: set.id, user_id: u.id, status: "approved",
            created_at: Time.current, updated_at: Time.current, }
        end,
      )
      record = build(:post_set_maintainer, post_set: set, user: invitee)
      expect(record).not_to be_valid
      expect(record.errors[:post_set]).to be_present
    end

    it "is valid when the set has fewer than 75 maintainers" do
      record = build(:post_set_maintainer, post_set: set, user: invitee)
      expect(record).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # ensure_not_duplicate
  # -------------------------------------------------------------------------
  describe "ensure_not_duplicate" do
    def seed_maintainer(status, created_at: Time.current)
      create(:post_set_maintainer, post_set: set, user: invitee).tap do |m|
        m.update_columns(status: status, created_at: created_at)
      end
    end

    it "is invalid when an approved record already exists for the same user and set" do
      seed_maintainer("approved")
      record = build(:post_set_maintainer, post_set: set, user: invitee)
      expect(record).not_to be_valid
      expect(record.errors[:base]).to include("Already a maintainer of this set")
    end

    it "is invalid when a pending record already exists for the same user and set" do
      seed_maintainer("pending")
      record = build(:post_set_maintainer, post_set: set, user: invitee)
      expect(record).not_to be_valid
      expect(record.errors[:base]).to include("Already a maintainer of this set")
    end

    it "is invalid when a blocked record exists for the same user and set" do
      seed_maintainer("blocked")
      record = build(:post_set_maintainer, post_set: set, user: invitee)
      expect(record).not_to be_valid
      expect(record.errors[:base]).to include("User has blocked you from inviting them to maintain this set")
    end

    it "is invalid when a cooldown record was created within the last 24 hours" do
      seed_maintainer("cooldown", created_at: 1.hour.ago)
      record = build(:post_set_maintainer, post_set: set, user: invitee)
      expect(record).not_to be_valid
      expect(record.errors[:base]).to include("User has been invited to maintain this set too recently")
    end

    it "is valid when a cooldown record was created more than 24 hours ago" do
      seed_maintainer("cooldown", created_at: 25.hours.ago)
      record = build(:post_set_maintainer, post_set: set, user: invitee)
      expect(record).to be_valid
    end

    it "is valid when no prior record exists for the user and set" do
      record = build(:post_set_maintainer, post_set: set, user: invitee)
      expect(record).to be_valid
    end
  end
end
