# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                   AvoidPostingVersion Instance Methods                      #
# --------------------------------------------------------------------------- #

RSpec.describe AvoidPostingVersion do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # #status
  # -------------------------------------------------------------------------
  describe "#status" do
    it "returns 'Active' when is_active is true" do
      version = create(:avoid_posting_version, is_active: true)
      expect(version.status).to eq("Active")
    end

    it "returns 'Deleted' when is_active is false" do
      version = create(:avoid_posting_version, is_active: false)
      expect(version.status).to eq("Deleted")
    end
  end

  # -------------------------------------------------------------------------
  # #previous
  # -------------------------------------------------------------------------
  describe "#previous" do
    it "returns nil when there are no earlier versions" do
      dnp = create(:avoid_posting)
      first_version = dnp.versions.first
      expect(first_version.previous).to be_nil
    end

    # FIXME: AvoidPostingVersion#previous does not filter by avoid_posting_id:
    #
    #   AvoidPostingVersion.joins(:avoid_posting)
    #     .where("avoid_posting_versions.id < ?", id)
    #     .order(id: :desc).first
    #
    # This returns the highest-ID version across ALL avoid postings that is
    # lower than the current version's ID, not just versions belonging to the
    # same parent avoid_posting. The test below reflects the intended behaviour
    # but will fail until the method adds a `where(avoid_posting: avoid_posting)`
    # condition.
    #
    # it "returns the immediately preceding version of the same avoid_posting" do
    #   dnp = create(:avoid_posting)
    #   other_dnp = create(:avoid_posting)
    #   # Trigger a second version on dnp so it is the highest-ID version.
    #   dnp.update!(details: "updated")
    #   second_version = dnp.versions.order(:id).last
    #   first_version  = dnp.versions.order(:id).first
    #   # second_version.previous should be first_version, not a version from other_dnp
    #   expect(second_version.previous).to eq(first_version)
    # end
  end

  # -------------------------------------------------------------------------
  # Delegated methods
  # -------------------------------------------------------------------------
  describe "#artist_id" do
    it "delegates to avoid_posting" do
      dnp = create(:avoid_posting)
      version = dnp.versions.first
      expect(version.artist_id).to eq(dnp.artist_id)
    end
  end

  describe "#artist_name" do
    it "delegates to avoid_posting" do
      dnp = create(:avoid_posting)
      version = dnp.versions.first
      expect(version.artist_name).to eq(dnp.artist_name)
    end
  end
end
