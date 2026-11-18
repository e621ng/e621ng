# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostEvent do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # #is_creator_visible?
  # -------------------------------------------------------------------------
  # can_view_flagger?(flagger_id) => user.is_staff? || user.id == flagger_id
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

  # -------------------------------------------------------------------------
  # #extra_data
  # -------------------------------------------------------------------------
  # The #extra_data accessor applies role-based filtering on top of the raw JSONB.
  # Tests for non-admin roles use CurrentUser.scoped to temporarily switch context
  # without interfering with the admin context set by include_context.
  describe "#extra_data" do
    it "returns the full extra_data hash for an admin" do
      event = create(:post_event, action: :deleted, extra_data: { reason: "spam", unexpected_key: "secret" })
      expect(event.extra_data).to include("reason" => "spam", "unexpected_key" => "secret")
    end

    it "strips unknown keys for a non-admin" do
      event = create(:post_event, action: :deleted, extra_data: { reason: "spam", unexpected_key: "secret" })
      member = create(:user)
      result = CurrentUser.scoped(member, "127.0.0.1") { event.extra_data }
      expect(result.keys).not_to include("unexpected_key")
    end

    it "returns an empty hash for a non-admin on an action with no known fields" do
      event = create(:post_event, action: :approved, extra_data: { unexpected_key: "secret" })
      member = create(:user)
      result = CurrentUser.scoped(member, "127.0.0.1") { event.extra_data }
      expect(result).to eq({})
    end

    it "strips storage_id for a non-admin on replacement_deleted even though it is a known field" do
      event = create(:post_event, action: :replacement_deleted, extra_data: { replacement_id: 1, md5: "abc", storage_id: "secret-path" })
      member = create(:user)
      result = CurrentUser.scoped(member, "127.0.0.1") { event.extra_data }
      expect(result.keys).not_to include("storage_id")
    end

    it "does not strip storage_id for an admin on replacement_deleted" do
      event = create(:post_event, action: :replacement_deleted, extra_data: { replacement_id: 1, md5: "abc", storage_id: "secret-path" })
      expect(event.extra_data).to include("storage_id" => "secret-path")
    end

    it "returns an empty hash when extra_data is not a Hash" do
      event = create(:post_event, action: :deleted)
      # Store an array in the JSONB column to trigger the non-Hash guard.
      event.update_columns(extra_data: [1, 2, 3])
      expect(event.extra_data).to eq({})
    end
  end
end
