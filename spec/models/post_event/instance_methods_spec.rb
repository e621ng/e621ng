# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostEvent do
  include_context "as admin"

  # --------------------------------------------------------------------------- #
  #                         #is_creator_visible?                                #
  # --------------------------------------------------------------------------- #
  # can_view_flagger?(flagger_id) => user.is_janitor? || user.id == flagger_id

  describe "#is_creator_visible?" do
    let(:flagger) { create(:user) }
    let(:post)    { create(:post) }

    context "for a non-flag_created event" do
      let(:event) { create(:post_event, action: :deleted) }

      it "is visible to a regular member" do
        expect(event.is_creator_visible?(create(:user))).to be true
      end

      it "is visible to a janitor" do
        expect(event.is_creator_visible?(create(:janitor_user))).to be true
      end
    end

    context "for a flag_created event" do
      let(:event) { create(:post_event, post_id: post.id, creator: flagger, action: :flag_created) }

      it "is visible to a janitor" do
        expect(event.is_creator_visible?(create(:janitor_user))).to be true
      end

      it "is visible to the creator (flagger) themselves" do
        expect(event.is_creator_visible?(flagger)).to be true
      end

      it "is not visible to an unrelated regular member" do
        expect(event.is_creator_visible?(create(:user))).to be false
      end
    end
  end
end
