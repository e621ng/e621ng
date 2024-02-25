# frozen_string_literal: true

require "test_helper"

class ParseValueTest < ActiveSupport::TestCase
  subject { ParseValue }

  def eq_value(input, type)
    subject.range(input, type)[1]
  end

  should "parse ranges" do
    assert_equal([:eq, 10], subject.range("10"))
    assert_equal([:lt, 10], subject.range("<10"))
    assert_equal([:lte, 10], subject.range("<=10"))
    assert_equal([:lte, 10], subject.range("..10"))
    assert_equal([:gt, 10], subject.range(">10"))
    assert_equal([:gte, 10], subject.range(">=10"))
    assert_equal([:gte, 10], subject.range("10.."))
    assert_equal([:between, 5, 15], subject.range("5..15"))
    assert_equal([:in, [8, 9, 10, 11, 12]], subject.range("8,9,10,11,12"))
  end

  should "parse floats" do
    assert_equal(10.0, eq_value("10", :float))
    assert_equal(0.1, eq_value(".1", :float))
    assert_equal(1.234, eq_value("1.234", :float))
  end

  should "parse ratios" do
    assert_equal(10.0, eq_value("10", :ratio))
    assert_equal(0.63, eq_value("5:8", :ratio))
    assert_equal(0.0, eq_value("10:0", :ratio))
  end

  should "parse floats" do
    assert_equal(10.0, eq_value("10", :float))
    assert_equal(0.1, eq_value(".1", :float))
    assert_equal(1.234, eq_value("1.234", :float))
  end

  should "parse filesizes" do
    assert_equal(10, eq_value("10", :filesize))
    assert_equal(102, eq_value(".1kb", :filesize))
    assert_equal(1024, eq_value("1KB", :filesize))
    assert_equal(50 * 1024, eq_value("50KB", :filesize))
    assert_equal(1.5 * 1024 * 1024, eq_value("1.5mb", :filesize))
  end

  should "invert ranges" do
    assert_equal([:eq, 10], subject.invert_range(subject.range("10")))
    assert_equal([:gt, 10], subject.invert_range(subject.range("<10")))
    assert_equal([:gte, 10], subject.invert_range(subject.range("<=10")))
    assert_equal([:lt, 10], subject.invert_range(subject.range(">10")))
    assert_equal([:lte, 10], subject.invert_range(subject.range(">=10")))
    assert_equal([:between, 15, 5], subject.invert_range(subject.range("5..15")))
    assert_equal([:in, [8, 9, 10, 11, 12]], subject.invert_range(subject.range("8,9,10,11,12")))
  end
end
