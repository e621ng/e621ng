# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        PostSet Class Methods                                #
# --------------------------------------------------------------------------- #

RSpec.describe PostSet do
  include_context "as member"

  # -------------------------------------------------------------------------
  # .name_to_id
  # -------------------------------------------------------------------------
  describe ".name_to_id" do
    it "returns the ID directly when given a numeric string" do
      set = create(:post_set)
      expect(PostSet.name_to_id(set.id.to_s)).to eq(set.id)
    end

    it "looks up the ID by shortname when given a non-numeric string" do
      set = create(:post_set, shortname: "my_lookup_set")
      expect(PostSet.name_to_id("my_lookup_set")).to eq(set.id)
    end

    it "is case-insensitive when looking up by shortname" do
      set = create(:post_set, shortname: "lookup_ci")
      expect(PostSet.name_to_id("LOOKUP_CI")).to eq(set.id)
    end

    it "converts spaces to underscores before looking up by shortname" do
      set = create(:post_set, shortname: "space_name")
      expect(PostSet.name_to_id("space name")).to eq(set.id)
    end

    it "returns 0 when no set matches the given shortname" do
      expect(PostSet.name_to_id("nonexistent_set")).to eq(0)
    end
  end

  # -------------------------------------------------------------------------
  # .visible
  # -------------------------------------------------------------------------
  describe ".visible" do
    let(:owner)     { CurrentUser.user }
    let(:other)     { create(:user) }
    let!(:pub_set)  { create(:public_post_set, creator: owner) }
    let!(:priv_set) { create(:post_set, is_public: false, creator: owner) }
    let!(:other_priv) { create(:post_set, is_public: false, creator: other) }

    it "returns only public sets when called with nil user" do
      result = PostSet.visible(nil)
      expect(result).to include(pub_set)
      expect(result).not_to include(priv_set, other_priv)
    end

    it "returns all sets for a moderator" do
      moderator = create(:moderator_user)
      result    = PostSet.visible(moderator)
      expect(result).to include(pub_set, priv_set, other_priv)
    end

    it "returns the user's own private sets plus all public sets for a regular member" do
      result = PostSet.visible(owner)
      expect(result).to include(pub_set, priv_set)
      expect(result).not_to include(other_priv)
    end

    it "returns only public sets for a different member" do
      result = PostSet.visible(other)
      expect(result).to include(pub_set, other_priv)
      expect(result).not_to include(priv_set)
    end
  end

  # -------------------------------------------------------------------------
  # .owned
  # -------------------------------------------------------------------------
  describe ".owned" do
    let(:owner) { CurrentUser.user }
    let(:other) { create(:user) }

    it "returns sets created by the given user" do
      owned = create(:post_set, creator: owner)
      expect(PostSet.owned(owner)).to include(owned)
    end

    it "does not return sets created by other users" do
      other_set = create(:post_set, creator: other)
      expect(PostSet.owned(owner)).not_to include(other_set)
    end
  end

  # -------------------------------------------------------------------------
  # .active_maintainer
  # -------------------------------------------------------------------------
  describe ".active_maintainer" do
    let(:owner)      { CurrentUser.user }
    let(:maintainer) { create(:user) }

    it "returns sets where the user has an approved maintainer record" do
      set = create(:public_post_set, creator: owner)
      create(:approved_post_set_maintainer, post_set: set, user: maintainer)
      expect(PostSet.active_maintainer(maintainer)).to include(set)
    end

    it "does not return sets where the user only has a pending maintainer record" do
      set = create(:public_post_set, creator: owner)
      create(:post_set_maintainer, post_set: set, user: maintainer)
      expect(PostSet.active_maintainer(maintainer)).not_to include(set)
    end

    it "does not return sets where the user is only the creator (no maintainer record)" do
      set = create(:public_post_set, creator: owner)
      expect(PostSet.active_maintainer(owner)).not_to include(set)
    end
  end
end
