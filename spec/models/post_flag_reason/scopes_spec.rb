# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostFlagReason do
  include_context "as admin"

  describe "scopes" do
    describe ".ordered" do
      context "with records at different index values" do
        let!(:high_index) { create(:post_flag_reason, name: "high", index: 10) }
        let!(:low_index)  { create(:post_flag_reason, name: "low",  index: 1) }
        let!(:mid_index)  { create(:post_flag_reason, name: "mid",  index: 5) }

        it "sorts by index ascending" do
          ids = PostFlagReason.ordered.ids
          expect(ids.index(low_index.id)).to be < ids.index(mid_index.id)
          expect(ids.index(mid_index.id)).to be < ids.index(high_index.id)
        end
      end

      context "when two records share the same index" do
        let!(:first)  { create(:post_flag_reason, name: "first",  index: 0) }
        let!(:second) { create(:post_flag_reason, name: "second", index: 0) }

        it "uses id ascending as a tiebreaker" do
          ids = PostFlagReason.ordered.ids
          expect(ids.index(first.id)).to be < ids.index(second.id)
        end
      end
    end
  end
end
