# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       PostDisapproval Validations                           #
# --------------------------------------------------------------------------- #

RSpec.describe PostDisapproval do
  include_context "as member"

  # -------------------------------------------------------------------------
  # reason — inclusion
  # -------------------------------------------------------------------------
  describe "reason — inclusion" do
    it "is invalid when reason is blank" do
      record = build(:post_disapproval, reason: "")
      expect(record).not_to be_valid
      expect(record.errors[:reason]).to be_present
    end

    it "is invalid when reason is an unsupported value" do
      record = build(:post_disapproval, reason: "spam")
      expect(record).not_to be_valid
      expect(record.errors[:reason]).to be_present
    end

    it "is invalid when reason is the DB default 'legacy'" do
      record = build(:post_disapproval, reason: "legacy")
      expect(record).not_to be_valid
      expect(record.errors[:reason]).to be_present
    end

    it "is valid with reason 'borderline_quality'" do
      expect(build(:post_disapproval, reason: "borderline_quality")).to be_valid
    end

    it "is valid with reason 'borderline_relevancy'" do
      expect(build(:post_disapproval, reason: "borderline_relevancy")).to be_valid
    end

    it "is valid with reason 'other'" do
      expect(build(:post_disapproval, reason: "other")).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # post_id — uniqueness scoped to user_id
  # -------------------------------------------------------------------------
  describe "post_id — uniqueness scoped to user_id" do
    let(:post) { create(:post) }
    let(:user) { create(:user) }

    it "is invalid when the same (post, user) pair already exists" do
      create(:post_disapproval, post: post, user: user)
      duplicate = build(:post_disapproval, post: post, user: user)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:post_id]).to include("have already hidden this post")
    end

    it "is valid when the same post is disapproved by a different user" do
      create(:post_disapproval, post: post, user: user)
      other_user = create(:user)
      expect(build(:post_disapproval, post: post, user: other_user)).to be_valid
    end

    it "is valid when the same user disapproves a different post" do
      create(:post_disapproval, post: post, user: user)
      other_post = create(:post)
      expect(build(:post_disapproval, post: other_post, user: user)).to be_valid
    end
  end
end
