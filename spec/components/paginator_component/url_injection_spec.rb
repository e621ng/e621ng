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

  def rendered_hrefs(**opts)
    doc = render_inline(described_class.new(records: make_records(**opts)))
    doc.css("a").pluck("href")
  end

  describe "reserved url_for keys injected via the query string" do
    it "does not let ?host= change the link host" do
      with_request_url "/posts?tags=cat&host=evil.example" do
        hrefs = rendered_hrefs
        expect(hrefs).to be_present
        expect(hrefs).to all(start_with("/posts?"))
        # host is preserved, but only as a query param
        expect(hrefs).to all(include("host=evil.example"))
      end
    end

    it "does not let ?protocol= or ?port= leak into the link target" do
      with_request_url "/posts?host=evil.example&protocol=ftp&port=1234" do
        expect(rendered_hrefs).to all(start_with("/posts?"))
      end
    end

    it "still keeps ordinary search params and swaps the page number" do
      with_request_url "/posts?tags=cat&host=evil.example" do
        doc = render_inline(described_class.new(records: make_records(mode: :numbered, current_page: 5)))
        href = doc.at_css("a#paginator-next")["href"]
        expect(href).to include("tags=cat")
        expect(href).to include("page=6")
      end
    end
  end
end
