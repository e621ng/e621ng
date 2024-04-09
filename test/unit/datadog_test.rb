# frozen_string_literal: true

require "test_helper"

class DatadogTest < ActiveSupport::TestCase
  def assert_match_group(expected, query)
    assert_equal(expected, query[SensitiveParams.to_datadog_regex])
  end

  def assert_no_match_group(query)
    assert_nil(query[SensitiveParams.to_datadog_regex])
  end

  should "filters query parameters" do
    assert_match_group("password=hunter2", "password=hunter2")
    assert_match_group("password=hunter2", "?abc=def&password=hunter2&foo=bar")
    # These partial matches are fine, just don't let datadog grab it
    assert_match_group("password]=hunter2", "?abc=def&user[password]=hunter2&foo=bar")
    assert_match_group("password=hunter2", "old_password=hunter2")
    assert_match_group("password_old=hunter2", "password_old=hunter2")

    assert_no_match_group("something=else")
    assert_no_match_group("search[foo]=bar")
  end
end
