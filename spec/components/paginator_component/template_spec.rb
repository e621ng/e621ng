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

  describe "nav element" do
    it "has the 'numbered' CSS class in numbered mode" do
      with_request_url "/posts" do
        doc = render_inline(described_class.new(records: make_records(mode: :numbered)))
        expect(doc.at_css("nav.pagination.numbered")).to be_present
      end
    end

    it "has the 'sequential' CSS class in sequential mode" do
      with_request_url "/posts" do
        doc = render_inline(described_class.new(records: make_records(mode: :sequential)))
        expect(doc.at_css("nav.pagination.sequential")).to be_present
      end
    end

    it "sets data-current to the current page number" do
      with_request_url "/posts" do
        doc = render_inline(described_class.new(records: make_records(current_page: 7)))
        expect(doc.at_css("nav.pagination")["data-current"]).to eq("7")
      end
    end

    it "sets data-total to the last page in numbered mode" do
      with_request_url "/posts" do
        doc = render_inline(described_class.new(records: make_records(mode: :numbered, total_pages: 20)))
        expect(doc.at_css("nav.pagination")["data-total"]).to eq("20")
      end
    end

    it "sets data-total to empty string in sequential mode" do
      with_request_url "/posts" do
        doc = render_inline(described_class.new(records: make_records(mode: :sequential)))
        expect(doc.at_css("nav.pagination")["data-total"]).to eq("")
      end
    end
  end

  describe "prev button" do
    it "renders a link when has_prev? is true" do
      with_request_url "/posts" do
        doc = render_inline(described_class.new(records: make_records(mode: :numbered, current_page: 5)))
        expect(doc.at_css("a#paginator-prev.prev")).to be_present
      end
    end

    it "renders a disabled span when has_prev? is false (page 1 in numbered mode)" do
      with_request_url "/posts" do
        doc = render_inline(described_class.new(records: make_records(mode: :numbered, current_page: 1)))
        expect(doc.at_css("span#paginator-prev.prev")).to be_present
        expect(doc.css("a#paginator-prev")).to be_empty
      end
    end

    it "renders a disabled span when has_prev? is false (first page in sequential mode)" do
      with_request_url "/posts" do
        doc = render_inline(described_class.new(records: make_records(mode: :sequential, is_first_page: true)))
        expect(doc.at_css("span#paginator-prev.prev")).to be_present
      end
    end

    it "has a data-hotkey='prev' attribute" do
      with_request_url "/posts" do
        doc = render_inline(described_class.new(records: make_records(mode: :numbered, current_page: 1)))
        expect(doc.at_css("[id='paginator-prev']")["data-hotkey"]).to eq("prev")
      end
    end

    it "links to page N-1 in numbered mode" do
      with_request_url "/posts" do
        doc = render_inline(described_class.new(records: make_records(mode: :numbered, current_page: 5)))
        href = doc.at_css("a#paginator-prev")["href"]
        expect(href).to include("page=4")
      end
    end

    it "links using the before-ID path in sequential mode" do
      with_request_url "/posts" do
        doc = render_inline(described_class.new(records: make_records(mode: :sequential, is_first_page: false, first_id: 123)))
        href = doc.at_css("a#paginator-prev")["href"]
        expect(href).to include("a123")
      end
    end
  end

  describe "next button" do
    it "renders a link when has_next? is true" do
      with_request_url "/posts" do
        doc = render_inline(described_class.new(records: make_records(mode: :numbered, current_page: 5, total_pages: 20)))
        expect(doc.at_css("a#paginator-next.next")).to be_present
      end
    end

    it "renders a disabled span when has_next? is false (last page in numbered mode)" do
      with_request_url "/posts" do
        doc = render_inline(described_class.new(records: make_records(mode: :numbered, current_page: 20, total_pages: 20)))
        expect(doc.at_css("span#paginator-next.next")).to be_present
        expect(doc.css("a#paginator-next")).to be_empty
      end
    end

    it "renders a disabled span when has_next? is false (last page in sequential mode)" do
      with_request_url "/posts" do
        doc = render_inline(described_class.new(records: make_records(mode: :sequential, is_last_page: true)))
        expect(doc.at_css("span#paginator-next.next")).to be_present
      end
    end

    it "has a data-hotkey='next' attribute" do
      with_request_url "/posts" do
        doc = render_inline(described_class.new(records: make_records(mode: :numbered, current_page: 20, total_pages: 20)))
        expect(doc.at_css("[id='paginator-next']")["data-hotkey"]).to eq("next")
      end
    end

    it "links to page N+1 in numbered mode" do
      with_request_url "/posts" do
        doc = render_inline(described_class.new(records: make_records(mode: :numbered, current_page: 5, total_pages: 20)))
        href = doc.at_css("a#paginator-next")["href"]
        expect(href).to include("page=6")
      end
    end

    it "links using the after-ID path in sequential mode" do
      with_request_url "/posts" do
        doc = render_inline(described_class.new(records: make_records(mode: :sequential, is_last_page: false, last_id: 456)))
        href = doc.at_css("a#paginator-next")["href"]
        expect(href).to include("b456")
      end
    end
  end

  describe "page numbers (numbered mode)" do
    it "renders no .page elements in sequential mode" do
      with_request_url "/posts" do
        doc = render_inline(described_class.new(records: make_records(mode: :sequential)))
        expect(doc.css(".page")).to be_empty
      end
    end

    it "marks the current page with aria-current='page'" do
      with_request_url "/posts" do
        doc = render_inline(described_class.new(records: make_records(mode: :numbered, current_page: 5, total_pages: 20)))
        current = doc.at_css(".page.current")
        expect(current).to be_present
        expect(current["aria-current"]).to eq("page")
        expect(current.text.strip).to eq("5")
      end
    end

    it "renders a .page.first link for page 1" do
      with_request_url "/posts" do
        doc = render_inline(described_class.new(records: make_records(mode: :numbered, current_page: 5, total_pages: 20)))
        expect(doc.at_css("a.page.first")).to be_present
      end
    end

    it "renders a .page.last link for the final page" do
      with_request_url "/posts" do
        doc = render_inline(described_class.new(records: make_records(mode: :numbered, current_page: 5, total_pages: 20)))
        expect(doc.at_css("a.page.last")).to be_present
      end
    end

    it "renders .page.spacer links when the window does not reach the edges" do
      with_request_url "/posts" do
        doc = render_inline(described_class.new(records: make_records(mode: :numbered, current_page: 5, total_pages: 20)))
        expect(doc.css("a.page.spacer").length).to eq(2)
      end
    end

    it "omits spacers when the window is adjacent to the edges (small set)" do
      with_request_url "/posts" do
        doc = render_inline(described_class.new(records: make_records(mode: :numbered, current_page: 2, total_pages: 3)))
        expect(doc.css("a.page.spacer")).to be_empty
      end
    end
  end
end
