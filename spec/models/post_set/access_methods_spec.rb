# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       PostSet Access Methods                                #
# --------------------------------------------------------------------------- #

RSpec.describe PostSet do
  include_context "as member"

  let(:owner)      { CurrentUser.user }
  let(:other_user) { create(:user) }
  let(:moderator)  { create(:moderator_user) }
  let(:admin)      { create(:admin_user) }

  # -------------------------------------------------------------------------
  # #can_view?
  # -------------------------------------------------------------------------
  describe "#can_view?" do
    it "returns true for any user when the set is public" do
      set = create(:public_post_set, creator: owner)
      expect(set.can_view?(other_user)).to be true
    end

    it "returns true for the owner when the set is private" do
      set = create(:post_set, is_public: false, creator: owner)
      expect(set.can_view?(owner)).to be true
    end

    it "returns true for a moderator when the set is private" do
      set = create(:post_set, is_public: false, creator: owner)
      expect(set.can_view?(moderator)).to be true
    end

    it "returns false for a non-owner regular user when the set is private" do
      set = create(:post_set, is_public: false, creator: owner)
      expect(set.can_view?(other_user)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #can_edit_settings?
  # -------------------------------------------------------------------------
  describe "#can_edit_settings?" do
    it "returns true for the set owner" do
      set = create(:post_set, creator: owner)
      expect(set.can_edit_settings?(owner)).to be true
    end

    it "returns true for an admin" do
      set = create(:post_set, creator: owner)
      expect(set.can_edit_settings?(admin)).to be true
    end

    it "returns false for a regular member who is not the owner" do
      set = create(:post_set, creator: owner)
      expect(set.can_edit_settings?(other_user)).to be false
    end

    it "returns false for a moderator who is not the owner" do
      set = create(:post_set, creator: owner)
      expect(set.can_edit_settings?(moderator)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #can_edit_posts?
  # -------------------------------------------------------------------------
  describe "#can_edit_posts?" do
    it "returns true for the set owner" do
      set = create(:post_set, creator: owner)
      expect(set.can_edit_posts?(owner)).to be true
    end

    it "returns true for an approved maintainer of a public set" do
      set = create(:public_post_set, creator: owner)
      create(:approved_post_set_maintainer, post_set: set, user: other_user)
      expect(set.can_edit_posts?(other_user)).to be true
    end

    it "returns false for an approved maintainer of a private set" do
      # PostSetMaintainer requires a public set on create; make private afterwards.
      set = create(:public_post_set, creator: owner)
      create(:approved_post_set_maintainer, post_set: set, user: other_user)
      set.update_columns(is_public: false)
      set.reload
      expect(set.can_edit_posts?(other_user)).to be false
    end

    it "returns false for a pending maintainer of a public set" do
      set = create(:public_post_set, creator: owner)
      create(:post_set_maintainer, post_set: set, user: other_user, status: "pending")
      expect(set.can_edit_posts?(other_user)).to be false
    end

    it "returns false for an unrelated user" do
      set = create(:public_post_set, creator: owner)
      expect(set.can_edit_posts?(other_user)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #is_owner?
  # -------------------------------------------------------------------------
  describe "#is_owner?" do
    it "returns true for the creator of the set" do
      set = create(:post_set, creator: owner)
      expect(set.is_owner?(owner)).to be true
    end

    it "returns false for a different user" do
      set = create(:post_set, creator: owner)
      expect(set.is_owner?(other_user)).to be false
    end

    it "returns false for a banned user even if they are the creator" do
      banned = create(:banned_user)
      CurrentUser.user = banned
      set = create(:post_set, creator: banned)
      expect(set.is_owner?(banned)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #is_maintainer?
  # -------------------------------------------------------------------------
  describe "#is_maintainer?" do
    it "returns true when the user has an approved maintainer record" do
      set = create(:public_post_set, creator: owner)
      create(:approved_post_set_maintainer, post_set: set, user: other_user)
      expect(set.is_maintainer?(other_user)).to be true
    end

    it "returns false when the user only has a pending maintainer record" do
      set = create(:public_post_set, creator: owner)
      create(:post_set_maintainer, post_set: set, user: other_user)
      expect(set.is_maintainer?(other_user)).to be false
    end

    it "returns false when the user has no maintainer record" do
      set = create(:public_post_set, creator: owner)
      expect(set.is_maintainer?(other_user)).to be false
    end

    it "returns false for a banned user even with an approved record" do
      banned = create(:banned_user)
      set    = create(:public_post_set, creator: owner)
      create(:approved_post_set_maintainer, post_set: set, user: banned)
      expect(set.is_maintainer?(banned)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #is_invited?
  # -------------------------------------------------------------------------
  describe "#is_invited?" do
    it "returns true when the user has a pending maintainer record" do
      set = create(:public_post_set, creator: owner)
      create(:post_set_maintainer, post_set: set, user: other_user, status: "pending")
      expect(set.is_invited?(other_user)).to be true
    end

    it "returns false when the user has no maintainer record" do
      set = create(:public_post_set, creator: owner)
      expect(set.is_invited?(other_user)).to be false
    end

    it "returns false when the user has an approved (not pending) record" do
      set = create(:public_post_set, creator: owner)
      create(:approved_post_set_maintainer, post_set: set, user: other_user)
      expect(set.is_invited?(other_user)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #is_blocked?
  # -------------------------------------------------------------------------
  describe "#is_blocked?" do
    it "returns true when the user has a blocked maintainer record" do
      set = create(:public_post_set, creator: owner)
      create(:blocked_post_set_maintainer, post_set: set, user: other_user)
      expect(set.is_blocked?(other_user)).to be true
    end

    it "returns false when the user has no maintainer record" do
      set = create(:public_post_set, creator: owner)
      expect(set.is_blocked?(other_user)).to be false
    end

    it "returns false when the user has an approved record" do
      set = create(:public_post_set, creator: owner)
      create(:approved_post_set_maintainer, post_set: set, user: other_user)
      expect(set.is_blocked?(other_user)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #is_over_limit?
  # -------------------------------------------------------------------------
  describe "#is_over_limit?" do
    it "returns false when post_count is at the limit" do
      max = Danbooru.config.post_set_post_limit.to_i
      set = create(:post_set)
      set.update_columns(post_count: max)
      expect(set.is_over_limit?).to be false
    end

    it "returns false when post_count is within the 100-post grace margin" do
      max = Danbooru.config.post_set_post_limit.to_i
      set = create(:post_set)
      set.update_columns(post_count: max + 50)
      expect(set.is_over_limit?).to be false
    end

    it "returns true when post_count exceeds the limit by more than 100" do
      max = Danbooru.config.post_set_post_limit.to_i
      set = create(:post_set)
      set.update_columns(post_count: max + 101)
      expect(set.is_over_limit?).to be true
    end
  end
end
