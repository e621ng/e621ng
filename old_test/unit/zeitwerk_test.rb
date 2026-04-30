# frozen_string_literal: true

require "test_helper"

class ZeitwerkTest < ActiveSupport::TestCase
  should "eager load all files without errors" do
    assert_nothing_raised { Rails.application.eager_load! }
  end
end
