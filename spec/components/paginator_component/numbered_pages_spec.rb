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

  def pages(component)
    component.send(:numbered_pages)
  end

  def page_numbers(component)
    pages(component).map(&:first)
  end

  def spacer_count(component)
    pages(component).count { |_, klass| klass == "spacer" }
  end

  describe "#numbered_pages" do
    it "always includes page 1 as the first entry" do
      expect(pages(component(current_page: 5, total_pages: 20)).first).to eq([1, "first"])
    end

    it "includes last_page as the final entry when last_page > 1" do
      expect(pages(component(current_page: 5, total_pages: 20)).last).to eq([20, "last"])
    end

    describe "middle page (5 of 20)" do
      subject(:c) { component(mode: :numbered, current_page: 5, total_pages: 20) }

      it "includes the window around the current page" do
        expect(page_numbers(c)).to include(4, 5, 6)
      end

      it "has a leading spacer because the window does not touch page 2" do
        leading = pages(c)[1]
        expect(leading).to eq([0, "spacer"])
      end

      it "has a trailing spacer because the window does not touch the last page" do
        expect(spacer_count(c)).to eq(2)
      end
    end

    describe "first page (1 of 20)" do
      subject(:c) { component(mode: :numbered, current_page: 1, total_pages: 20) }

      it "includes a right-shifted window" do
        expect(page_numbers(c)).to include(2, 3, 4, 5)
      end

      it "does not have a leading spacer because the window starts at page 2" do
        expect(pages(c)[1]).not_to eq([0, "spacer"])
      end

      it "has a trailing spacer" do
        expect(spacer_count(c)).to eq(1)
      end
    end

    describe "last page (20 of 20)" do
      subject(:c) { component(mode: :numbered, current_page: 20, total_pages: 20) }

      it "includes a left-shifted window" do
        expect(page_numbers(c)).to include(15, 16, 17, 18, 19)
      end

      it "has a leading spacer" do
        expect(spacer_count(c)).to be >= 1
      end

      it "does not have a trailing spacer because the window ends at the page before last" do
        second_to_last = pages(c)[-2]
        expect(second_to_last).not_to eq([0, "spacer"])
      end
    end

    describe "near-start page (3 of 20)" do
      subject(:c) { component(mode: :numbered, current_page: 3, total_pages: 20) }

      it "includes pages 2 through 6 with no leading spacer" do
        expect(page_numbers(c)).to include(2, 3, 4, 5)
        expect(pages(c)[1]).not_to eq([0, "spacer"])
      end

      it "has a trailing spacer" do
        expect(spacer_count(c)).to eq(1)
      end
    end

    describe "near-end page (18 of 20)" do
      subject(:c) { component(mode: :numbered, current_page: 18, total_pages: 20) }

      it "includes pages up to 19 with no trailing spacer" do
        expect(page_numbers(c)).to include(15, 16, 17, 18, 19)
        second_to_last = pages(c)[-2]
        expect(second_to_last).not_to eq([0, "spacer"])
      end

      it "has a leading spacer" do
        expect(spacer_count(c)).to eq(1)
      end
    end

    describe "small set — 2 pages, page 1" do
      subject(:c) { component(mode: :numbered, current_page: 1, total_pages: 2) }

      it "contains only page 1 and page 2" do
        expect(pages(c)).to eq([[1, "first"], [2, "last"]])
      end

      it "has no spacers" do
        expect(spacer_count(c)).to eq(0)
      end
    end

    describe "small set — 3 pages, page 2" do
      subject(:c) { component(mode: :numbered, current_page: 2, total_pages: 3) }

      it "contains page 1, page 2, and page 3 with no spacers" do
        expect(pages(c)).to eq([[1, "first"], [2, ""], [3, "last"]])
      end

      it "has no spacers" do
        expect(spacer_count(c)).to eq(0)
      end
    end
  end
end
