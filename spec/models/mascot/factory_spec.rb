# frozen_string_literal: true

RSpec.describe Mascot do
  include_context "as admin"

  it "has a valid factory" do
    expect(build(:mascot)).to be_valid
  end

  it "can be persisted" do
    expect { create(:mascot) }.to change(Mascot, :count).by(1)
  end

  describe ":inactive_mascot factory" do
    it "creates an inactive mascot" do
      expect(create(:inactive_mascot).active).to be false
    end
  end

  describe ":app_mascot factory" do
    it "includes the current app name in available_on" do
      expect(create(:app_mascot).available_on).to include(Danbooru.config.app_name)
    end
  end
end
