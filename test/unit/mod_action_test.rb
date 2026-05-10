# frozen_string_literal: true

require "test_helper"

class ModActionTest < ActiveSupport::TestCase
  context "ModAction.search" do
    setup do
      CurrentUser.user = create(:admin_user)
    end

    context "when filtering by an integer-typed JSONB field" do
      setup do
        @ban_30 = create(:mod_action, action: "user_ban", values: { "user_id" => 1, "duration" => 30, "reason" => "x" })
        @ban_7  = create(:mod_action, action: "user_ban", values: { "user_id" => 2, "duration" => 7, "reason" => "y" })
        # Older user_ban rows can hold the string "permanent" under the
        # integer-typed `duration` key; an unconditional `::INTEGER` cast
        # would raise PG::InvalidTextRepresentation across the whole result.
        @ban_permanent = create(:mod_action, action: "user_ban", values: { "user_id" => 3, "duration" => "permanent", "reason" => "z" })
      end

      should "return matching integer rows without raising on non-integer rows" do
        results = ModAction.search(action: "user_ban", duration: "30")
        assert_equal([@ban_30.id], results.map(&:id))
      end

      should "support range syntax without raising on non-integer rows" do
        results = ModAction.search(action: "user_ban", duration: "1..29")
        assert_equal([@ban_7.id], results.map(&:id))
      end

      should "skip non-integer values rather than matching them" do
        # The "permanent" row must never appear in any integer-comparison result,
        # not even when the duration parameter is empty (which falls through to
        # the action-only filter and would expose any cast that ran on every row).
        all_user_bans = ModAction.search(action: "user_ban").map(&:id)
        assert_includes(all_user_bans, @ban_permanent.id)

        empty_match = ModAction.search(action: "user_ban", duration: "999999")
        assert_empty(empty_match.to_a)
      end
    end
  end
end
