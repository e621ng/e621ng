# frozen_string_literal: true

require "rails_helper"

RSpec.describe SearchTrendAggregateJob do
  def perform
    described_class.perform_now
  end

  let(:past_hour)    { 1.day.ago.utc.beginning_of_day + 12.hours }
  let(:current_hour) { Time.current.utc.beginning_of_hour }

  describe "#perform" do
    context "when there are no unprocessed hourly records" do
      it "does not create any daily records" do
        expect { perform }.not_to change(SearchTrend, :count)
      end
    end

    context "when all unprocessed records are within the last hour" do
      let!(:recent_record) { create(:search_trend_hourly, hour: current_hour) }

      it "does not process recent records" do
        perform
        expect(recent_record.reload.processed).to be false
      end

      it "does not create any daily records" do
        expect { perform }.not_to change(SearchTrend, :count)
      end
    end

    context "when there is a single unprocessed record older than 1 hour" do
      let!(:hourly) { create(:search_trend_hourly, tag: "search_tag", hour: past_hour, count: 5) }

      it "creates one daily SearchTrend record" do
        expect { perform }.to change(SearchTrend, :count).by(1)
      end

      it "sets the correct count on the daily record" do
        perform
        trend = SearchTrend.find_by(tag: "search_tag", day: past_hour.to_date)
        expect(trend.count).to eq(5)
      end

      it "marks the hourly record as processed" do
        perform
        expect(hourly.reload.processed).to be true
      end
    end

    context "when multiple hourly records exist for the same tag and day" do
      let!(:later_hourly)   { create(:search_trend_hourly, tag: "search_tag", hour: past_hour, count: 3) }
      let!(:earlier_hourly) { create(:search_trend_hourly, tag: "search_tag", hour: past_hour - 1.hour, count: 7) }

      it "creates only one daily record" do
        expect { perform }.to change(SearchTrend, :count).by(1)
      end

      it "sums hourly counts into the daily record" do
        perform
        trend = SearchTrend.find_by(tag: "search_tag", day: past_hour.to_date)
        expect(trend.count).to eq(10)
      end

      it "marks all hourly records as processed" do
        perform
        expect(later_hourly.reload.processed).to be true
        expect(earlier_hourly.reload.processed).to be true
      end
    end

    context "when hourly records exist for multiple different tags on the same day" do
      before do
        create(:search_trend_hourly, tag: "tag_alpha", hour: past_hour, count: 2)
        create(:search_trend_hourly, tag: "tag_beta",  hour: past_hour, count: 4)
      end

      it "creates one daily record per tag" do
        expect { perform }.to change(SearchTrend, :count).by(2)
      end

      it "stores the correct count for each tag" do
        perform
        expect(SearchTrend.find_by(tag: "tag_alpha", day: past_hour.to_date).count).to eq(2)
        expect(SearchTrend.find_by(tag: "tag_beta",  day: past_hour.to_date).count).to eq(4)
      end
    end

    context "when a daily record already exists for the tag" do
      let!(:existing) { create(:search_trend, tag: "existing_tag", day: past_hour.to_date, count: 10) }

      before { create(:search_trend_hourly, tag: "existing_tag", hour: past_hour, count: 5) }

      it "increments the existing daily record count" do
        perform
        expect(existing.reload.count).to eq(15)
      end

      it "does not create a duplicate daily record" do
        expect { perform }.not_to change(SearchTrend, :count)
      end
    end

    context "when hourly records are already processed" do
      before { create(:search_trend_hourly, hour: past_hour, count: 3, processed: true) }

      it "does not create daily records for already-processed records" do
        expect { perform }.not_to change(SearchTrend, :count)
      end
    end
  end
end
