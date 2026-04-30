# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostEvent do
  include_context "as admin"

  describe "factory" do
    it "produces a valid post_event" do
      expect(create(:post_event)).to be_persisted
    end
  end
end
