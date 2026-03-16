# frozen_string_literal: true

require "test_helper"

class AwardTest < ActiveSupport::TestCase
  context "An award" do
    setup do
      @admin = create(:admin_user)
      @janitor = create(:janitor_user)
      @user = create(:user)
      @award_type = as(@admin) { create(:award_type) }
      CurrentUser.user = @janitor
    end

    should "be valid when given by staff" do
      award = build(:award, award_type: @award_type, user: @user, creator: @janitor)
      assert award.valid?
    end

    should "enforce uniqueness of award type per user" do
      create(:award, award_type: @award_type, user: @user, creator: @janitor)
      duplicate = build(:award, award_type: @award_type, user: @user, creator: @janitor)
      assert duplicate.invalid?
      assert duplicate.errors[:award_type_id].any?
    end

    context "#can_destroy?" do
      setup do
        @award = as(@janitor) { create(:award, award_type: @award_type, user: @user, creator: @janitor) }
      end

      should "allow the awarding staff member to revoke" do
        assert @award.can_destroy?(@janitor)
      end

      should "allow an admin to revoke" do
        assert @award.can_destroy?(@admin)
      end

      should "deny a different staff member" do
        other_janitor = create(:janitor_user)
        assert_not @award.can_destroy?(other_janitor)
      end

      should "deny a regular member" do
        assert_not @award.can_destroy?(@user)
      end
    end
  end
end
