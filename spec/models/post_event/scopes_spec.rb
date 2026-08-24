# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                            PostEvent Scopes                                 #
# --------------------------------------------------------------------------- #

RSpec.describe PostEvent do
  include_context "as admin"

  let(:post)    { create(:post) }
  let(:creator) { create(:user) }

  describe "scopes" do
    # -------------------------------------------------------------------------
    # .visible
    # -------------------------------------------------------------------------
    describe ".visible" do
      let!(:regular_event)   { PostEvent.add(post.id, creator, :deleted) }
      let!(:protected_event) { PostEvent.add(post.id, creator, :replacement_penalty_changed, replacement_id: 1, penalize: true) }

      it "returns all records for a staff user (moderator)" do
        staff  = create(:moderator_user)
        result = PostEvent.visible(staff)
        expect(result).to include(regular_event, protected_event)
      end

      it "returns all records for a staff user (janitor)" do
        staff  = create(:janitor_user)
        result = PostEvent.visible(staff)
        expect(result).to include(regular_event, protected_event)
      end

      it "excludes protected actions for a regular member" do
        member = create(:user)
        result = PostEvent.visible(member)
        expect(result).not_to include(protected_event)
      end

      it "includes non-protected actions for a regular member" do
        member = create(:user)
        result = PostEvent.visible(member)
        expect(result).to include(regular_event)
      end
    end
  end
end
