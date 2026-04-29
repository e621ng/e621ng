# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserNameChangeRequest do
  include_context "as member"

  # ------------------------------------------------------------------ #
  # initialize_attributes (after_initialize on new records)            #
  # ------------------------------------------------------------------ #
  describe "#initialize_attributes" do
    it "sets user_id from CurrentUser when not provided" do
      record = UserNameChangeRequest.new(desired_name: "something_new")
      expect(record.user_id).to eq(CurrentUser.user.id)
    end

    it "sets original_name from CurrentUser when not provided" do
      record = UserNameChangeRequest.new(desired_name: "something_new")
      expect(record.original_name).to eq(CurrentUser.user.name)
    end

    it "does not overwrite an explicitly provided user_id" do
      other_user = create(:user)
      record = UserNameChangeRequest.new(user_id: other_user.id, desired_name: "something_new")
      expect(record.user_id).to eq(other_user.id)
    end

    it "does not overwrite an explicitly provided original_name" do
      record = UserNameChangeRequest.new(original_name: "explicit_name", desired_name: "something_new")
      expect(record.original_name).to eq("explicit_name")
    end
  end

  # ------------------------------------------------------------------ #
  # apply! — renames the associated user                               #
  # ------------------------------------------------------------------ #
  describe "#apply!" do
    it "updates the user's name to desired_name after creation" do
      request = create(:user_name_change_request, desired_name: "brand_new_name")
      expect(request.user.reload.name).to eq("brand_new_name")
    end

    it "updates the user's name when called directly on an existing record" do
      request = create(:user_name_change_request, desired_name: "first_name")
      request.desired_name = "second_name"
      request.apply!
      expect(request.user.reload.name).to eq("second_name")
    end
  end
end
