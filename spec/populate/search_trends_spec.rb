# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/populate")

RSpec.describe Populate::SearchTrends do
  include_context "as admin"

  it "creates daily and hourly rows" do
    expect { described_class.new(days: 2, hours: 3, tags_count: 4, hourly_tags_count: 2).call }.to output.to_stdout

    expect(SearchTrend.count).to eq(8)
    expect(SearchTrend.distinct.count(:tag)).to eq(4)
    expect(SearchTrendHourly.count).to eq(6)
    expect(SearchTrendHourly.unprocessed.count).to eq(6)
  end

  it "does nothing for zero days and hours" do
    expect(described_class.new(days: 0, hours: 0).call).to be_nil
    expect(SearchTrend.count).to eq(0)
  end
end
