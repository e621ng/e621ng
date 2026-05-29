# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsersHelper do
  let(:user) { build(:user) }
  let(:former_staff) { build(:former_staff_user) }
  let(:moderator) { build(:moderator_user) }
  let(:admin) { build(:admin_user) }

  describe "#user_level_badge" do
    it "returns nil if the user is nil" do
      expect(helper.user_level_badge(nil)).to be_nil
    end

    it "displays the level string in uppercase" do
      badge_html = helper.user_level_badge(user)
      expect(badge_html).to include("MEMBER")
    end

    it "includes the correct CSS class for the user's level" do
      expect(helper.user_level_badge(user)).to include("user-member")
      expect(helper.user_level_badge(former_staff)).to include("user-former-staff")
      expect(helper.user_level_badge(moderator)).to include("user-moderator")
      expect(helper.user_level_badge(admin)).to include("user-admin")
    end
  end

  describe "#user_custom_title_badge" do
    it "returns nil if the user is nil" do
      expect(helper.user_custom_title_badge(nil)).to be_nil
    end

    context "when user has a custom title" do
      it "displays the custom title in uppercase" do
        user.custom_title = "Custom Title"

        badge_html = helper.user_custom_title_badge(user)
        expect(badge_html).to include("CUSTOM TITLE")
      end
    end

    context "when user does not have a custom title" do
      it "returns nil" do
        expect(helper.user_custom_title_badge(user)).to be_nil
      end
    end
  end

  describe "#user_level_plain" do
    it "returns nil if the user is nil" do
      expect(helper.user_level_plain(nil)).to be_nil
    end

    context "when user has a custom title" do
      it "returns the custom title" do
        user.custom_title = "Custom Title"

        expect(helper.user_level_plain(user)).to eq("Custom Title")
      end
    end

    context "when user does not have a custom title" do
      it "returns the level string" do
        user.custom_title = nil

        expect(helper.user_level_plain(user)).to eq("Member")
      end
    end
  end

  describe "#user_bd_staff_badge" do
    it "returns nil if the user is nil" do
      expect(helper.user_bd_staff_badge(nil)).to be_nil
    end

    context "when user is BD staff" do
      it "displays the BD STAFF badge" do
        user.is_bd_staff = true

        badge_html = helper.user_bd_staff_badge(user)
        expect(badge_html).to include("BD STAFF")
      end
    end

    context "when user is not BD staff" do
      it "returns nil" do
        user.is_bd_staff = false

        expect(helper.user_bd_staff_badge(user)).to be_nil
      end
    end
  end
end
