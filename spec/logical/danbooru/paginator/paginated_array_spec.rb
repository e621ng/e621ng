# frozen_string_literal: true

require "rails_helper"

RSpec.describe Danbooru::Paginator::PaginatedArray do
  def paginated_array(records:, pagination_mode:, records_per_page: 2, current_page: 1, total_count: 0)
    described_class.new(
      records,
      pagination_mode: pagination_mode,
      records_per_page: records_per_page,
      current_page: current_page,
      total_count: total_count,
    )
  end

  describe "sequential empty-page boundaries" do
    it "treats an empty sequential_before page as both first and last" do
      records = paginated_array(records: [], pagination_mode: :sequential_before)

      expect(records.is_first_page?).to be(true)
      expect(records.is_last_page?).to be(true)
    end

    it "treats an empty sequential_after page as both first and last" do
      records = paginated_array(records: [], pagination_mode: :sequential_after)

      expect(records.is_first_page?).to be(true)
      expect(records.is_last_page?).to be(true)
    end
  end
end
