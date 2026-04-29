# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           ModAction Search                                  #
# --------------------------------------------------------------------------- #

RSpec.describe ModAction do
  include_context "as admin"

  def make_action(action_name, values = {})
    ModAction.log(action_name, values)
  end

  describe ".search" do
    # -------------------------------------------------------------------------
    # action param
    # -------------------------------------------------------------------------
    describe "action param" do
      it "returns records matching the given action" do
        feedback      = make_action(:user_feedback_create, { user_id: 1 })
        other_action  = make_action(:blip_delete, { blip_id: 2, user_id: 1 })

        result = ModAction.search(action: "user_feedback_create")
        expect(result).to include(feedback)
        expect(result).not_to include(other_action)
      end
    end

    # -------------------------------------------------------------------------
    # creator_id param (via where_user helper)
    # -------------------------------------------------------------------------
    describe "creator_id param" do
      it "returns only records created by the specified user" do
        current_admin = CurrentUser.user
        other_creator = create(:user)

        own_action = make_action(:user_feedback_create, { user_id: 1 })

        # Temporarily create an action as a different user.
        other_action = CurrentUser.scoped(other_creator, "127.0.0.1") do
          make_action(:user_feedback_create, { user_id: 2 })
        end

        result = ModAction.search(creator_id: current_admin.id)
        expect(result).to include(own_action)
        expect(result).not_to include(other_action)
      end
    end

    # -------------------------------------------------------------------------
    # JSONB integer field
    # -------------------------------------------------------------------------
    # ModAction.search applies JSONB sub-filters using string-keyed params
    # (params.slice(*field_types.keys.map(&:to_s))). Pass JSONB field names
    # as string keys to ensure they are picked up by the slice operation.
    describe "JSONB integer field (user_id on user_feedback_create)" do
      it "filters records by an integer JSONB attribute" do
        user_a = create(:user)
        user_b = create(:user)

        action_a = make_action(:user_feedback_create, { user_id: user_a.id, reason: "complaint", type: "negative", record_id: 1 })
        action_b = make_action(:user_feedback_create, { user_id: user_b.id, reason: "complaint", type: "negative", record_id: 2 })

        result = ModAction.search(action: "user_feedback_create", "user_id" => user_a.id.to_s)
        expect(result).to include(action_a)
        expect(result).not_to include(action_b)
      end
    end

    # -------------------------------------------------------------------------
    # JSONB string field — exact (full-text search)
    # -------------------------------------------------------------------------
    describe "JSONB string field exact match (reason on user_feedback_create)" do
      it "returns records whose reason matches the query term" do
        matching     = make_action(:user_feedback_create, { user_id: 1, reason: "harassment complaint filed", type: "negative", record_id: 1 })
        non_matching = make_action(:user_feedback_create, { user_id: 2, reason: "positive contribution", type: "positive", record_id: 2 })

        result = ModAction.search(action: "user_feedback_create", "reason" => "harassment")
        expect(result).to include(matching)
        expect(result).not_to include(non_matching)
      end
    end

    # -------------------------------------------------------------------------
    # JSONB string field — wildcard (LIKE search)
    # -------------------------------------------------------------------------
    describe "JSONB string field wildcard match" do
      it "returns records whose reason matches the wildcard pattern" do
        matching     = make_action(:user_feedback_create, { user_id: 1, reason: "rule violation", type: "negative", record_id: 1 })
        non_matching = make_action(:user_feedback_create, { user_id: 2, reason: "great artist", type: "positive", record_id: 2 })

        result = ModAction.search(action: "user_feedback_create", "reason" => "rule*")
        expect(result).to include(matching)
        expect(result).not_to include(non_matching)
      end
    end

    # -------------------------------------------------------------------------
    # JSONB boolean field
    # -------------------------------------------------------------------------
    describe "JSONB boolean field (is_public on set_change_visibility)" do
      it "returns records where is_public is true when searching for true" do
        public_action  = make_action(:set_change_visibility, { set_id: 1, user_id: 1, is_public: true })
        private_action = make_action(:set_change_visibility, { set_id: 2, user_id: 1, is_public: false })

        result = ModAction.search(action: "set_change_visibility", "is_public" => "true")
        expect(result).to include(public_action)
        expect(result).not_to include(private_action)
      end

      it "returns records where is_public is false when searching for false" do
        public_action  = make_action(:set_change_visibility, { set_id: 1, user_id: 1, is_public: true })
        private_action = make_action(:set_change_visibility, { set_id: 2, user_id: 1, is_public: false })

        result = ModAction.search(action: "set_change_visibility", "is_public" => "false")
        expect(result).to include(private_action)
        expect(result).not_to include(public_action)
      end
    end

    # -------------------------------------------------------------------------
    # Unknown action — no JSONB sub-filters applied
    # -------------------------------------------------------------------------
    describe "unknown action param" do
      it "does not raise an error for an unknown action" do
        make_action(:user_feedback_create, { user_id: 1 })
        expect { ModAction.search(action: "nonexistent_action").to_a }.not_to raise_error
      end
    end

    # -------------------------------------------------------------------------
    # Default ordering
    # -------------------------------------------------------------------------
    describe "default ordering" do
      it "returns newer records before older records" do
        older = make_action(:user_feedback_create, { user_id: 1 })
        newer = make_action(:user_feedback_create, { user_id: 2 })

        older.update_columns(created_at: 1.hour.ago)

        ids = ModAction.search({}).ids
        expect(ids.index(newer.id)).to be < ids.index(older.id)
      end
    end
  end
end
