# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                     UploadWhitelist Callbacks                               #
# --------------------------------------------------------------------------- #

RSpec.describe UploadWhitelist do
  let(:moderator) { create(:moderator_user) }

  before { CurrentUser.user = moderator }
  after  { CurrentUser.user = nil }

  describe "callbacks" do
    # -------------------------------------------------------------------------
    # after_save :clear_cache
    # -------------------------------------------------------------------------
    describe "after_save :clear_cache" do
      it "clears the upload_whitelist cache on create" do
        allow(Cache).to receive(:delete)
        create(:upload_whitelist)
        expect(Cache).to have_received(:delete).with("upload_whitelist").at_least(:once)
      end

      it "clears the upload_whitelist cache on update" do
        entry = create(:upload_whitelist)
        allow(Cache).to receive(:delete)
        entry.update!(note: "updated note")
        expect(Cache).to have_received(:delete).with("upload_whitelist").at_least(:once)
      end
    end

    # -------------------------------------------------------------------------
    # after_create: logs :upload_whitelist_create
    # -------------------------------------------------------------------------
    describe "after_create: upload_whitelist_create" do
      it "logs an upload_whitelist_create action with the entry's attributes" do
        create(:upload_whitelist, domain: "pics\\.example\\.com", path: "\\/images\\/.+", note: "image host", hidden: false)
        log = ModAction.where(action: "upload_whitelist_create").last

        expect(log).to be_present
        expect(log[:values]).to include(
          "domain" => "pics\\.example\\.com",
          "path"   => "\\/images\\/.+",
          "note"   => "image host",
          "hidden" => false,
        )
      end
    end

    # -------------------------------------------------------------------------
    # after_save: logs :upload_whitelist_update (fires on both create and update)
    # -------------------------------------------------------------------------
    describe "after_save: upload_whitelist_update" do
      it "logs an upload_whitelist_update action on create" do
        create(:upload_whitelist)
        log = ModAction.where(action: "upload_whitelist_update").last
        expect(log).to be_present
      end

      it "logs an upload_whitelist_update action on update with old values" do
        entry = create(:upload_whitelist, domain: "old\\.domain\\.com", path: "\\/old\\/.+")

        entry.update!(domain: "new\\.domain\\.com", path: "\\/new\\/.+")
        log = ModAction.where(action: "upload_whitelist_update").last

        expect(log).to be_present
        expect(log[:values]).to include(
          "domain"     => "new\\.domain\\.com",
          "path"       => "\\/new\\/.+",
          "old_domain" => "old\\.domain\\.com",
          "old_path"   => "\\/old\\/.+",
        )
      end
    end

    # -------------------------------------------------------------------------
    # after_destroy: logs :upload_whitelist_delete
    # -------------------------------------------------------------------------
    describe "after_destroy: upload_whitelist_delete" do
      it "logs an upload_whitelist_delete action with the entry's attributes" do
        entry = create(:upload_whitelist, domain: "gone\\.com", path: "\\/.+", note: "to be removed", hidden: true)
        entry.destroy!
        log = ModAction.where(action: "upload_whitelist_delete").last

        expect(log).to be_present
        expect(log[:values]).to include(
          "domain" => "gone\\.com",
          "path"   => "\\/.+",
          "note"   => "to be removed",
          "hidden" => true,
        )
      end
    end
  end
end
