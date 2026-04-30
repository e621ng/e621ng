# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                      AvoidPosting Version Methods                           #
# --------------------------------------------------------------------------- #

RSpec.describe AvoidPosting do
  include_context "as admin"

  def make_dnp(overrides = {})
    create(:avoid_posting, **overrides)
  end

  # -------------------------------------------------------------------------
  # #create_version — on create
  # -------------------------------------------------------------------------
  describe "#create_version on create" do
    it "creates one version when the record is first created" do
      dnp = make_dnp(details: "some details", staff_notes: "staff note", is_active: true)
      expect(dnp.versions.count).to eq(1)
    end

    it "snapshots details on create" do
      dnp = make_dnp(details: "initial details")
      expect(dnp.versions.last.details).to eq("initial details")
    end

    it "snapshots staff_notes on create" do
      dnp = make_dnp(staff_notes: "initial notes")
      expect(dnp.versions.last.staff_notes).to eq("initial notes")
    end

    it "snapshots is_active on create" do
      dnp = make_dnp(is_active: true)
      expect(dnp.versions.last.is_active).to be true
    end
  end

  # -------------------------------------------------------------------------
  # #create_version — on update of watched attributes
  # -------------------------------------------------------------------------
  describe "#create_version on update" do
    it "creates a new version when details changes" do
      dnp = make_dnp
      expect { dnp.update!(details: "new details") }
        .to change { dnp.versions.count }.by(1)
    end

    it "creates a new version when is_active changes" do
      dnp = make_dnp
      expect { dnp.update!(is_active: false) }
        .to change { dnp.versions.count }.by(1)
    end

    it "creates a new version when staff_notes changes" do
      dnp = make_dnp
      expect { dnp.update!(staff_notes: "new notes") }
        .to change { dnp.versions.count }.by(1)
    end

    it "does not create a version when update_columns bypasses callbacks" do
      dnp = make_dnp
      expect { dnp.update_columns(updated_at: 1.second.from_now) }
        .not_to(change { dnp.versions.count })
    end

    it "snapshots the new details value in the version" do
      dnp = make_dnp(details: "old details")
      dnp.update!(details: "new details")
      expect(dnp.versions.last.details).to eq("new details")
    end
  end
end
