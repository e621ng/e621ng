# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsersHelper do
  let(:user) { build(:user) }

  describe "#user_level_badge" do
    context "when user has a custom title" do
      it "displays the custom title in uppercase" do
        user.custom_title = "Custom Title"

        badge_html = helper.user_level_badge(user)
        expect(badge_html).to include("CUSTOM TITLE")
      end
    end

    context "when user does not have a custom title" do
      it "displays the level string in uppercase" do
        user.custom_title = nil

        badge_html = helper.user_level_badge(user)
        expect(badge_html).to include("MEMBER")
      end
    end
  end

  describe "#user_level_plain" do
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
    context "when user is BD staff" do
      it "displays the BD STAFF badge" do
        user.is_bd_staff = true

        badge_html = helper.user_bd_staff_badge(user)
        expect(badge_html).to include("BD STAFF")
      end
    end

    context "when user is not BD staff" do
      it "does not display the BD STAFF badge" do
        user.is_bd_staff = false

        badge_html = helper.user_bd_staff_badge(user)
        expect(badge_html).to be_nil
      end
    end
  end
end
