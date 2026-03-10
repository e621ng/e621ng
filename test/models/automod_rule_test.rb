# frozen_string_literal: true

require "test_helper"

class AutomodRuleTest < ActiveSupport::TestCase
  context "An AutomodRule" do
    setup do
      @admin = create(:admin_user)
      CurrentUser.user = @admin
    end

    teardown do
      CurrentUser.user = nil
    end

    context "validations" do
      should "be valid with valid attributes" do
        rule = build(:automod_rule, name: "test_rule", regex: "spam")
        assert(rule.valid?)
      end

      should "require a name" do
        rule = build(:automod_rule, name: "")
        assert(rule.invalid?)
        assert_includes(rule.errors[:name], "can't be blank")
      end

      should "require a unique name" do
        create(:automod_rule, name: "duplicate")
        rule = build(:automod_rule, name: "duplicate")
        assert(rule.invalid?)
        assert_includes(rule.errors[:name], "has already been taken")
      end

      should "require a regex" do
        rule = build(:automod_rule, regex: "")
        assert(rule.invalid?)
        assert_includes(rule.errors[:regex], "can't be blank")
      end

      should "reject an invalid regex" do
        rule = build(:automod_rule, regex: "[invalid")
        assert(rule.invalid?)
        assert(rule.errors[:regex].any? { |e| e.start_with?("is invalid") })
      end

      should "accept a valid regex" do
        rule = build(:automod_rule, regex: "(?i)spam|scam")
        assert(rule.valid?)
      end
    end

    context "#match?" do
      should "return true when the regex matches" do
        rule = build(:automod_rule, regex: "spam")
        assert(rule.match?("this is spam content"))
      end

      should "return false when the regex does not match" do
        rule = build(:automod_rule, regex: "spam")
        assert_not(rule.match?("perfectly normal comment"))
      end

      should "return false when the regex is invalid" do
        rule = build(:automod_rule, regex: "[invalid")
        assert_not(rule.match?("text"))
      end
    end

    context ".enabled scope" do
      should "only return enabled rules" do
        enabled_rule  = create(:automod_rule, enabled: true)
        disabled_rule = create(:automod_rule, enabled: false)
        enabled_ids = AutomodRule.enabled.pluck(:id)
        assert_includes(enabled_ids, enabled_rule.id)
        assert_not_includes(enabled_ids, disabled_rule.id)
      end
    end
  end
end
