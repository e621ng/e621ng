# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       UploadWhitelist Factory Checks                        #
# --------------------------------------------------------------------------- #

RSpec.describe UploadWhitelist do
  # ModAction.log (after_create / after_save callbacks) calls initialize_creator
  # which reads CurrentUser.id. A moderator is used to satisfy that requirement.
  before { CurrentUser.user = create(:moderator_user) }
  after  { CurrentUser.user = nil }

  describe "factory" do
    it "produces a valid allowed entry" do
      expect(create(:upload_whitelist)).to be_persisted
    end

    it "produces a valid blocked entry" do
      expect(create(:blocked_upload_whitelist)).to be_persisted
    end
  end
end
