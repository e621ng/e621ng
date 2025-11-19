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

  should "parse negative values" do
    assert_equal([:lt, -1], subject.range("<-1"))
  end

  should "clamp huge values" do
    assert_equal(ParseValue::MAX_INT, eq_value("1234567890987654321", :integer))
    assert_equal(ParseValue::MIN_INT, eq_value("-1234567890987654321", :integer))
    assert_equal(ParseValue::MAX_INT, eq_value("123456789098765432.1", :float))
    assert_equal(ParseValue::MIN_INT, eq_value("-123456789098765432.1", :float))
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

  should "return nil for dates with years outside OpenSearch range" do
    # Invalid years in OpenSearch
    assert_nil(eq_value("23025-05-24", :date))
    assert_nil(eq_value("10000-01-01", :date))
    assert_nil(eq_value("-1-01-01", :date))

    # Valid years
    assert_not_nil(eq_value("2025-05-24", :date))
    assert_not_nil(eq_value("0001-01-01", :date))
    assert_not_nil(eq_value("9999-12-31", :date))
  end

  should "return nil for malformed date formats" do
    # Malformed date with comma instead of underscore should return nil array element
    result = subject.date_range("2_,years_ago")
    assert_equal(:in, result[0])
    assert_includes(result[1], nil) # Contains nil which will trigger @has_invalid_input

    # Invalid date returns nil
    assert_nil(subject.date_from("invalid_date"))
    assert_equal([:eq, nil], subject.date_range("invalid_date"))

    # Comma-separated list with invalid dates contains nil values
    result = subject.date_range("2025-01-01,invalid,2025-06-01")
    assert_equal(:in, result[0])
    assert_equal(3, result[1].length)
    assert_includes(result[1], nil) # Contains nil which will trigger @has_invalid_input
  end

  should "parse valid date formats correctly" do
    # Standard date format
    result = subject.date_range("2025-11-18")
    assert_equal(:eq, result[0])
    assert result[1].is_a?(Time)

    # Ago format
    result = subject.date_range("2_years_ago")
    assert_equal(:gte, result[0])
    assert result[1].is_a?(Time)

    # Yesterday format returns :eq with a Date
    result = subject.date_range("yesterday")
    assert_equal(:eq, result[0])
    assert result[1].is_a?(Date)

    # Valid comma-separated dates (no nils)
    result = subject.date_range("2025-01-01,2025-06-01")
    assert_equal(:in, result[0])
    assert_equal(2, result[1].length)
    assert(result[1].all? { |date| date.is_a?(Time) })
    assert result[1].none?(&:nil?)
  end
end
