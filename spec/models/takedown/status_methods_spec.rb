# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        Takedown StatusMethods                               #
# --------------------------------------------------------------------------- #

RSpec.describe Takedown do
  subject(:takedown) { create(:takedown) }

  include_context "as admin"

  # -------------------------------------------------------------------------
  # completed?
  # -------------------------------------------------------------------------
  describe "#completed?" do
    %w[approved denied partial].each do |completed_status|
      it "returns true when status is '#{completed_status}'" do
        takedown.update_columns(status: completed_status)
        expect(takedown.completed?).to be true
      end
    end

    it "returns false when status is 'pending'" do
      takedown.update_columns(status: "pending")
      expect(takedown.completed?).to be false
    end
  end

  # -------------------------------------------------------------------------
  # calculated_status
  # -------------------------------------------------------------------------
  describe "#calculated_status" do
    context "when all posts are marked for deletion" do
      it "returns 'approved'" do
        takedown.update_columns(post_ids: "1 2", del_post_ids: "1 2")
        takedown.clear_cached_arrays
        expect(takedown.calculated_status).to eq("approved")
      end
    end

    context "when no posts are marked for deletion" do
      it "returns 'denied'" do
        takedown.update_columns(post_ids: "1 2", del_post_ids: "")
        takedown.clear_cached_arrays
        expect(takedown.calculated_status).to eq("denied")
      end
    end

    context "when some posts are marked for deletion and some are kept" do
      it "returns 'partial'" do
        takedown.update_columns(post_ids: "1 2 3", del_post_ids: "1")
        takedown.clear_cached_arrays
        expect(takedown.calculated_status).to eq("partial")
      end
    end

    context "when post_ids is empty" do
      # FIXME: this is a potential bug — with no posts at all, kept_count == 0,
      # so the method returns 'approved' even though nothing was actually processed.
      it "returns 'approved' (both kept and deleted counts are zero)" do
        takedown.update_columns(post_ids: "", del_post_ids: "")
        takedown.clear_cached_arrays
        expect(takedown.calculated_status).to eq("approved")
      end
    end
  end
end
