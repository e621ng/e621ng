# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       UploadWhitelist Validations                           #
# --------------------------------------------------------------------------- #

RSpec.describe UploadWhitelist do
  before { CurrentUser.user = create(:moderator_user) }
  after  { CurrentUser.user = nil }

  describe "validations" do
    # -------------------------------------------------------------------------
    # domain
    # -------------------------------------------------------------------------
    describe "domain" do
      it "is invalid without a domain" do
        entry = build(:upload_whitelist, domain: nil)
        expect(entry).not_to be_valid
        expect(entry.errors[:domain]).to be_present
      end

      it "is invalid with a blank domain" do
        entry = build(:upload_whitelist, domain: "")
        expect(entry).not_to be_valid
        expect(entry.errors[:domain]).to be_present
      end

      it "is valid with a domain present" do
        entry = build(:upload_whitelist, domain: "example\\.com")
        expect(entry).to be_valid
      end
    end

    # -------------------------------------------------------------------------
    # path
    # -------------------------------------------------------------------------
    describe "path" do
      it "is invalid without a path" do
        entry = build(:upload_whitelist, path: nil)
        expect(entry).not_to be_valid
        expect(entry.errors[:path]).to be_present
      end

      it "is invalid with a blank path" do
        entry = build(:upload_whitelist, path: "")
        expect(entry).not_to be_valid
        expect(entry.errors[:path]).to be_present
      end

      it "is valid with a path present" do
        entry = build(:upload_whitelist, path: "\\/.+")
        expect(entry).to be_valid
      end
    end
  end
end
