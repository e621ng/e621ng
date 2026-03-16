# frozen_string_literal: true

require "test_helper"

class AwardTypeTest < ActiveSupport::TestCase
  context "An award type" do
    setup do
      @admin = create(:admin_user)
      CurrentUser.user = @admin
    end

    should "be valid with a name" do
      award_type = build(:award_type, name: "Best Contributor")
      assert award_type.valid?
    end

    should "require a name" do
      award_type = build(:award_type, name: "")
      assert award_type.invalid?
      assert_includes award_type.errors[:name], "can't be blank"
    end

    should "enforce unique names case-insensitively" do
      create(:award_type, name: "Best Contributor")
      duplicate = build(:award_type, name: "best contributor")
      assert duplicate.invalid?
      assert award_type_has_uniqueness_error(duplicate)
    end
  end

  private

  def award_type_has_uniqueness_error(award_type)
    award_type.errors[:name].any? { |e| e =~ /taken/i }
  end
end
