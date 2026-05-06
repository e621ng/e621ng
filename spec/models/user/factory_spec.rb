# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                             Factory sanity checks                           #
# --------------------------------------------------------------------------- #

RSpec.describe User do
  describe "factory" do
    ###### User Levels ######

    it "produces a valid user" do
      expect(build(:user)).to be_valid
    end

    it "produces a valid banned user" do
      expect(build(:banned_user)).to be_valid
    end

    it "produces a valid janitor user" do
      expect(build(:janitor_user)).to be_valid
    end

    it "produces a valid moderator user" do
      expect(build(:moderator_user)).to be_valid
    end

    it "produces a valid admin user" do
      expect(build(:admin_user)).to be_valid
    end

    ### Permission Flags ####
    it "produces an unlimited uploads user" do
      expect(build(:unlimited_uploads_user)).to be_valid
    end

    it "produces an approver user" do
      expect(build(:approver_user)).to be_valid
    end
  end

  describe "callbacks" do
    it "creates a UserStatus record after creating a user" do
      user = create(:user)
      expect(user.user_status).to be_present
      expect(user.user_status.user_id).to eq(user.id)

      expect(UserStatus.for_user(user.id)).to include(user.user_status)
    end
  end
end
