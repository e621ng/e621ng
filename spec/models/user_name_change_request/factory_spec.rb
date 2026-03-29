# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserNameChangeRequest do
  include_context "as member"

  describe "factory" do
    it "produces a valid, persisted record" do
      expect(create(:user_name_change_request)).to be_persisted
    end

    it "applies the name change on creation (user name equals desired_name after create)" do
      request = create(:user_name_change_request)
      expect(request.user.reload.name).to eq(request.desired_name)
    end
  end
end
