# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        NoteVersion Factory Sanity                           #
# --------------------------------------------------------------------------- #

RSpec.describe NoteVersion do
  include_context "as admin"

  describe "factory" do
    subject(:version) { create(:note_version) }

    it "produces a valid, persisted record" do
      expect(version).to be_persisted
    end

    it "belongs to a note" do
      expect(version.note).to be_a(Note)
    end

    it "belongs to a post" do
      expect(version.post).to be_a(Post)
    end

    it "belongs to an updater" do
      expect(version.updater).to be_a(User)
    end

    it "has a non-blank body" do
      expect(version.body).to be_present
    end

    it "has geometry attributes" do
      expect(version.x).to be_present
      expect(version.y).to be_present
      expect(version.width).to be_present
      expect(version.height).to be_present
    end

    it "has an updater_ip_addr" do
      expect(version.updater_ip_addr).to be_present
    end
  end
end
