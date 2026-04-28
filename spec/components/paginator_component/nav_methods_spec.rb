# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaginatorComponent, type: :component do
  def make_records(**opts)
    opts = { mode: :numbered, current_page: 5, total_pages: 20, max_numbered_pages: 750,
             is_first_page: false, is_last_page: false, first_id: 100, last_id: 200, }.merge(opts)
    instance_double(
      Danbooru::Paginator::PaginatedArray,
      pagination_mode:    opts[:mode],
      current_page:       opts[:current_page],
      total_pages:        opts[:total_pages],
      max_numbered_pages: opts[:max_numbered_pages],
      is_first_page?:     opts[:is_first_page],
      is_last_page?:      opts[:is_last_page],
      first:              instance_double(Post, id: opts[:first_id]),
      last:               instance_double(Post, id: opts[:last_id]),
    )
  end

  def component(**overrides)
    described_class.new(records: make_records(**overrides))
  end

  describe "#has_prev?" do
    context "in numbered mode" do
      it "returns false on page 1" do
        expect(component(mode: :numbered, current_page: 1).send(:has_prev?)).to be false
      end

      it "returns true on page 2" do
        expect(component(mode: :numbered, current_page: 2).send(:has_prev?)).to be true
      end

      it "returns true on a middle page" do
        expect(component(mode: :numbered, current_page: 5).send(:has_prev?)).to be true
      end
    end

    context "in sequential mode" do
      it "returns false when records report it is the first page" do
        expect(component(mode: :sequential, is_first_page: true).send(:has_prev?)).to be false
      end

      it "returns true when records report it is not the first page" do
        expect(component(mode: :sequential, is_first_page: false).send(:has_prev?)).to be true
      end
    end
  end

  describe "#has_next?" do
    context "in numbered mode" do
      it "returns true when current_page is before last_page" do
        expect(component(mode: :numbered, current_page: 5, total_pages: 20).send(:has_next?)).to be true
      end

      it "returns false when current_page equals last_page" do
        expect(component(mode: :numbered, current_page: 20, total_pages: 20).send(:has_next?)).to be false
      end

      it "returns false when current_page is beyond last_page" do
        expect(component(mode: :numbered, current_page: 21, total_pages: 20).send(:has_next?)).to be false
      end

      it "is true when current_page is before the max_numbered_pages cap, even if total_pages is larger" do
        # last_page = min(1000, 10) = 10; mode stays :numbered (5 < 10)
        expect(component(mode: :numbered, current_page: 5, total_pages: 1000, max_numbered_pages: 10).send(:has_next?)).to be true
      end
    end

    context "in sequential mode" do
      it "returns false when records report it is the last page" do
        expect(component(mode: :sequential, is_last_page: true).send(:has_next?)).to be false
      end

      it "returns true when records report it is not the last page" do
        expect(component(mode: :sequential, is_last_page: false).send(:has_next?)).to be true
      end
    end
  end
end
