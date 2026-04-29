# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaginationHelper do
  def make_records(**opts)
    opts = {
      pagination_mode: :numbered, current_page: 1,
      records_per_page: 20, total_pages: 5,
      max_numbered_pages: 750, is_last_page: false, size: 20,
    }.merge(opts)
    instance_double(
      Danbooru::Paginator::PaginatedArray,
      pagination_mode:    opts[:pagination_mode],
      current_page:       opts[:current_page],
      records_per_page:   opts[:records_per_page],
      total_pages:        opts[:total_pages],
      max_numbered_pages: opts[:max_numbered_pages],
      is_last_page?:      opts[:is_last_page],
      size:               opts[:size],
    )
  end

  before do
    allow(helper).to receive(:params).and_return(
      ActionController::Parameters.new(controller: "posts", action: "index"),
    )
  end

  describe "#approximate_count" do
    let(:span) { Nokogiri::HTML.fragment(helper.approximate_count(records)).at_css("span.approximate-count") }

    context "when pagination_mode is :sequential_before" do
      let(:records) { make_records(pagination_mode: :sequential_before) }

      it { expect(helper.approximate_count(records)).to eq("") }
    end

    context "when pagination_mode is :sequential_after" do
      let(:records) { make_records(pagination_mode: :sequential_after) }

      it { expect(helper.approximate_count(records)).to eq("") }
    end

    context "when pagination_mode is :sequential" do
      let(:records) { make_records(pagination_mode: :sequential) }

      it { expect(helper.approximate_count(records)).to eq("") }
    end

    context "on the last page" do
      let(:records) { make_records(current_page: 3, records_per_page: 20, size: 5, is_last_page: true) }

      it "renders the approximate-count span" do
        expect(span).not_to be_nil
      end

      it "shows the exact count with no prefix" do
        expect(span.text).to eq("45 results")
      end

      it "uses comma-delimited formatting in the title" do
        expect(span["title"]).to include("Exactly 45 results found.")
      end

      it "sets data-count to the exact count" do
        expect(span["data-count"]).to eq("45")
      end

      it "sets data-pages to the current page" do
        expect(span["data-pages"]).to eq("3")
      end

      it "sets data-per to max_numbered_pages" do
        expect(span["data-per"]).to eq("750")
      end

      context "when there is exactly 1 result" do
        let(:records) { make_records(current_page: 1, records_per_page: 20, size: 1, is_last_page: true) }

        it "uses singular 'result'" do
          expect(span.text).to eq("1 result")
        end
      end
    end

    context "when total_pages exceeds max_numbered_pages" do
      let(:records) { make_records(total_pages: 1000, max_numbered_pages: 750, records_per_page: 20, is_last_page: false) }

      it "renders the approximate-count span" do
        expect(span).not_to be_nil
      end

      it "prefixes the count with 'over '" do
        expect(span.text).to start_with("over ")
      end

      it "shows the capped count in human-readable form" do
        expect(span.text).to include("15k results")
      end

      it "includes the capped count in the title" do
        expect(span["title"]).to include("Over 15,000 results found.")
      end

      it "sets data-count to max_numbered_pages * records_per_page" do
        expect(span["data-count"]).to eq("15000")
      end

      it "sets data-pages to max_numbered_pages" do
        expect(span["data-pages"]).to eq("750")
      end

      it "sets data-per to max_numbered_pages" do
        expect(span["data-per"]).to eq("750")
      end
    end

    context "on a normal numbered page" do
      let(:records) { make_records(current_page: 5, total_pages: 10, records_per_page: 20, is_last_page: false) }

      it "renders the approximate-count span" do
        expect(span).not_to be_nil
      end

      it "prefixes the count with '~'" do
        expect(span.text).to start_with("~")
      end

      it "includes 'Approximately' in the title" do
        expect(span["title"]).to include("Approximately")
      end

      it "includes 'results found.' in the title" do
        expect(span["title"]).to include("results found.")
      end

      it "produces a count within the expected RNG bounds" do
        count = span["data-count"].to_i
        min = (9 * 20) + (0.2 * 20).floor
        max = (9 * 20) + (0.8 * 20).ceil
        expect(count).to be_between(min, max)
      end

      it "produces the same count on repeated calls for the same params" do
        count_a = Nokogiri::HTML.fragment(helper.approximate_count(records)).at_css("span")["data-count"]
        count_b = Nokogiri::HTML.fragment(helper.approximate_count(records)).at_css("span")["data-count"]
        expect(count_a).to eq(count_b)
      end

      it "sets data-pages to total_pages" do
        expect(span["data-pages"]).to eq("10")
      end

      it "sets data-per to max_numbered_pages" do
        expect(span["data-per"]).to eq("750")
      end
    end
  end
end
