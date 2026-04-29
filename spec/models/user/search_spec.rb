# frozen_string_literal: true

require "rails_helper"

RSpec.describe User do
  describe ".search" do
    describe "flair_color_hex param" do
      it "matches wildcard hex prefixes" do
        first_user = create(:user)
        second_user = create(:user)
        third_user = create(:user)

        first_user.update!(flair_color_hex: "#abcdef")
        second_user.update!(flair_color_hex: "abc123")
        third_user.update!(flair_color_hex: "00ff00")

        result_ids = User.search(flair_color_hex: "abc*").pluck(:id)
        expect(result_ids).to include(first_user.id, second_user.id)
        expect(result_ids).not_to include(third_user.id)

        all_color_ids = User.search(flair_color_hex: "*").pluck(:id)
        expect(all_color_ids).to include(first_user.id, second_user.id, third_user.id)
      end
    end
  end
end
