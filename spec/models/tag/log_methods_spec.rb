# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           Tag::LogMethods                                   #
# --------------------------------------------------------------------------- #

RSpec.describe Tag do
  include_context "as admin"

  describe "after_destroy :log_destroy" do
    it "creates a ModAction record with action tag_destroy when a tag is destroyed" do
      tag = create(:tag, name: "log_destroy_test")
      expect { tag.destroy }.to change(ModAction, :count).by(1)
      mod_action = ModAction.last
      expect(mod_action.action).to eq("tag_destroy")
    end

    it "records the tag's name in the ModAction values" do
      tag = create(:tag, name: "logged_tag_name")
      tag.destroy
      mod_action = ModAction.last
      expect(mod_action.values["name"]).to eq("logged_tag_name")
    end
  end
end
