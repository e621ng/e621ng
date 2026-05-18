# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                     PostSetMaintainer Scopes                                #
# --------------------------------------------------------------------------- #

RSpec.describe PostSetMaintainer do
  include_context "as member"

  let(:owner) { CurrentUser.user }
  let(:set)   { create(:public_post_set, creator: owner) }

  let!(:approved_record) { create(:approved_post_set_maintainer, post_set: set) }
  let!(:pending_record)  { create(:post_set_maintainer,          post_set: set) }
  let!(:blocked_record)  { create(:blocked_post_set_maintainer,  post_set: set) }

  # -------------------------------------------------------------------------
  # .active
  # -------------------------------------------------------------------------
  describe ".active" do
    it "includes approved records" do
      expect(PostSetMaintainer.active).to include(approved_record)
    end

    it "excludes pending records" do
      expect(PostSetMaintainer.active).not_to include(pending_record)
    end

    it "excludes blocked records" do
      expect(PostSetMaintainer.active).not_to include(blocked_record)
    end
  end

  # -------------------------------------------------------------------------
  # .pending
  # -------------------------------------------------------------------------
  describe ".pending" do
    it "includes pending records" do
      expect(PostSetMaintainer.pending).to include(pending_record)
    end

    it "excludes approved records" do
      expect(PostSetMaintainer.pending).not_to include(approved_record)
    end

    it "excludes blocked records" do
      expect(PostSetMaintainer.pending).not_to include(blocked_record)
    end
  end
end
