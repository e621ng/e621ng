# frozen_string_literal: true

require "test_helper"

class ConditionalSearchCountTest < ActiveSupport::TestCase
  # Test class that includes the concern
  class TestHelper
    include ConditionalSearchCount

    attr_accessor :params

    def initialize(params = {})
      @params = params
    end
  end

  context "ConditionalSearchCount" do
    context "#search_count_params" do
      should "return nil when no narrowing parameters are present" do
        helper = TestHelper.new(search: { order: "created_at" })
        result = helper.search_count_params(narrowing: [:id])
        assert_nil result
      end

      should "return search params when narrowing parameter has value" do
        search_params = { id: "123", order: "created_at" }
        helper = TestHelper.new(search: search_params)
        result = helper.search_count_params(narrowing: [:id])
        assert_equal search_params, result
      end

      should "return search params when truthy parameter is true" do
        search_params = { is_sticky: "true" }
        helper = TestHelper.new(search: search_params)
        result = helper.search_count_params(truthy: [:is_sticky])
        assert_equal search_params, result
      end

      should "return nil when truthy parameter is false" do
        helper = TestHelper.new(search: { is_sticky: "false" })
        result = helper.search_count_params(truthy: [:is_sticky])
        assert_nil result
      end

      should "return search params when falsy parameter is false" do
        search_params = { is_hidden: "false" }
        helper = TestHelper.new(search: search_params)
        result = helper.search_count_params(falsy: [:is_hidden])
        assert_equal search_params, result
      end

      should "return nil when falsy parameter is true" do
        helper = TestHelper.new(search: { is_hidden: "true" })
        result = helper.search_count_params(falsy: [:is_hidden])
        assert_nil result
      end

      should "handle multiple narrowing parameters" do
        search_params = { id: "", name: "test" }
        helper = TestHelper.new(search: search_params)
        result = helper.search_count_params(narrowing: %i[id name])
        assert_equal search_params, result
      end

      should "handle combination of narrowing, truthy, and falsy parameters" do
        search_params = { name: "", is_hidden: "false", is_sticky: "false" }
        helper = TestHelper.new(search: search_params)
        result = helper.search_count_params(
          narrowing: [:name],
          truthy: [:is_sticky],
          falsy: [:is_hidden],
        )
        assert_equal search_params, result
      end
    end
  end
end
