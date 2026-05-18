# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       AvoidPosting Log Methods                              #
# --------------------------------------------------------------------------- #

RSpec.describe AvoidPosting do
  include_context "as admin"

  def make_dnp(overrides = {})
    create(:avoid_posting, **overrides)
  end

  # -------------------------------------------------------------------------
  # #log_create
  # -------------------------------------------------------------------------
  describe "#log_create" do
    it "logs an avoid_posting_create action when a record is created" do
      expect { make_dnp }.to change(ModAction.where(action: "avoid_posting_create"), :count).by(1)
    end

    it "records the id and artist_name in ModAction values" do
      dnp = make_dnp
      log = ModAction.where(action: "avoid_posting_create").last
      expect(log[:values]).to include("id" => dnp.id, "artist_name" => dnp.artist_name)
    end
  end

  # -------------------------------------------------------------------------
  # #log_destroy
  # -------------------------------------------------------------------------
  describe "#log_destroy" do
    it "logs an avoid_posting_destroy action when a record is destroyed" do
      dnp = make_dnp
      expect { dnp.destroy! }.to change(ModAction.where(action: "avoid_posting_destroy"), :count).by(1)
    end

    it "records the id and artist_name captured before destruction" do
      dnp = make_dnp
      dnp_id       = dnp.id
      artist_name  = dnp.artist_name
      dnp.destroy!
      log = ModAction.where(action: "avoid_posting_destroy").last
      expect(log[:values]).to include("id" => dnp_id, "artist_name" => artist_name)
    end
  end

  # -------------------------------------------------------------------------
  # #log_update — is_active only (early return)
  # -------------------------------------------------------------------------
  describe "#log_update — soft-delete" do
    it "logs avoid_posting_delete when is_active changes to false" do
      dnp = make_dnp
      expect { dnp.update!(is_active: false) }.to change(ModAction.where(action: "avoid_posting_delete"), :count).by(1)
    end

    it "does NOT log avoid_posting_update when only is_active changes to false" do
      dnp = make_dnp
      expect { dnp.update!(is_active: false) }.not_to change(ModAction.where(action: "avoid_posting_update"), :count)
    end

    it "records id and artist_name for the delete action" do
      dnp = make_dnp
      dnp.update!(is_active: false)
      log = ModAction.where(action: "avoid_posting_delete").last
      expect(log[:values]).to include("id" => dnp.id, "artist_name" => dnp.artist_name)
    end
  end

  describe "#log_update — undelete" do
    it "logs avoid_posting_undelete when is_active changes to true" do
      dnp = make_dnp(is_active: false)
      expect { dnp.update!(is_active: true) }.to change(ModAction.where(action: "avoid_posting_undelete"), :count).by(1)
    end

    it "does NOT log avoid_posting_update when only is_active changes to true" do
      dnp = make_dnp(is_active: false)
      expect { dnp.update!(is_active: true) }.not_to change(ModAction.where(action: "avoid_posting_update"), :count)
    end
  end

  # -------------------------------------------------------------------------
  # #log_update — details changed only
  # -------------------------------------------------------------------------
  describe "#log_update — details changed" do
    it "logs avoid_posting_update when only details changes" do
      dnp = make_dnp(details: "original details")
      expect { dnp.update!(details: "updated details") }.to change(ModAction.where(action: "avoid_posting_update"), :count).by(1)
    end

    it "records details and old_details in the update ModAction" do
      dnp = make_dnp(details: "original details")
      dnp.update!(details: "updated details")
      log = ModAction.where(action: "avoid_posting_update").last
      expect(log[:values]).to include(
        "id"          => dnp.id,
        "artist_name" => dnp.artist_name,
        "details"     => "updated details",
        "old_details" => "original details",
      )
    end
  end

  # -------------------------------------------------------------------------
  # #log_update — staff_notes changed only
  # -------------------------------------------------------------------------
  describe "#log_update — staff_notes changed" do
    it "logs avoid_posting_update when only staff_notes changes" do
      dnp = make_dnp(staff_notes: "original notes")
      expect { dnp.update!(staff_notes: "updated notes") }.to change(ModAction.where(action: "avoid_posting_update"), :count).by(1)
    end

    it "records staff_notes and old_staff_notes in the update ModAction" do
      dnp = make_dnp(staff_notes: "original notes")
      dnp.update!(staff_notes: "updated notes")
      log = ModAction.where(action: "avoid_posting_update").last
      expect(log[:values]).to include(
        "staff_notes"     => "updated notes",
        "old_staff_notes" => "original notes",
      )
    end
  end

  # -------------------------------------------------------------------------
  # #log_update — is_active + details changed (compound)
  # -------------------------------------------------------------------------
  describe "#log_update — is_active and details changed together" do
    it "logs both avoid_posting_delete and avoid_posting_update" do
      dnp = make_dnp(details: "original details")
      expect { dnp.update!(is_active: false, details: "updated details") }
        .to change(ModAction, :count).by(2)
      actions = ModAction.last(2).map(&:action)
      expect(actions).to include("avoid_posting_delete", "avoid_posting_update")
    end
  end
end
