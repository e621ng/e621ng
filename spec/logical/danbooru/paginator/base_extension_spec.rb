# frozen_string_literal: true

require "rails_helper"

RSpec.describe Danbooru::Paginator::BaseExtension do
  let(:klass) do
    Class.new do
      include Danbooru::Paginator::BaseExtension

      def paginate_numbered
        self
      end

      def paginate_sequential_before
        self
      end

      def paginate_sequential_after
        self
      end
    end
  end
  let(:relation) { klass.new }

  describe "#parse_limit" do
    it "falls back to the configured default when the limit is blank" do
      relation.paginate(nil, limit: nil)
      expect(relation.records_per_page).to eq(Danbooru.config.records_per_page)

      relation.paginate(nil, limit: "")
      expect(relation.records_per_page).to eq(Danbooru.config.records_per_page)
    end

    it "accepts integers between 0 and the configured max" do
      relation.paginate(nil, limit: 0)
      expect(relation.records_per_page).to eq(0)

      relation.paginate(nil, limit: Danbooru.config.max_per_page)
      expect(relation.records_per_page).to eq(Danbooru.config.max_per_page)
    end

    it "accepts numeric strings in range" do
      relation.paginate(nil, limit: "50")
      expect(relation.records_per_page).to eq(50)
    end

    it "raises on integers outside the allowed range" do
      expect { relation.paginate(nil, limit: -1) }.to raise_error(Danbooru::Paginator::PaginationError)
      expect { relation.paginate(nil, limit: Danbooru.config.max_per_page + 1) }.to raise_error(Danbooru::Paginator::PaginationError)
    end

    it "raises on negative string values" do
      expect { relation.paginate(nil, limit: "-1") }.to raise_error(Danbooru::Paginator::PaginationError, /Invalid limit/)
    end

    it "raises on float strings" do
      expect { relation.paginate(nil, limit: "10.5") }.to raise_error(Danbooru::Paginator::PaginationError, /Invalid limit/)
    end

    it "raises on non-numeric strings" do
      expect { relation.paginate(nil, limit: "abc") }.to raise_error(Danbooru::Paginator::PaginationError, /Invalid limit/)
    end

    it "raises on hash values" do
      expect { relation.paginate(nil, limit: { foo: 1 }) }.to raise_error(Danbooru::Paginator::PaginationError, /Invalid limit/)
    end

    it "raises on array values" do
      expect { relation.paginate(nil, limit: [1, 2]) }.to raise_error(Danbooru::Paginator::PaginationError, /Invalid limit/)
    end
  end

  describe "#parse_page" do
    it "defaults to page 1 in numbered mode when blank" do
      relation.paginate(nil)
      expect(relation.current_page).to eq(1)
      expect(relation.pagination_mode).to eq(:numbered)

      relation.paginate("")
      expect(relation.current_page).to eq(1)
      expect(relation.pagination_mode).to eq(:numbered)
    end

    context "with a numbered page" do
      it "accepts integers from 1 up to max_numbered_pages" do
        relation.paginate("1")
        expect(relation.current_page).to eq(1)

        relation.paginate(Danbooru.config.max_numbered_pages.to_s)
        expect(relation.current_page).to eq(Danbooru.config.max_numbered_pages)
      end

      it "raises on page 0" do
        expect { relation.paginate("0") }.to raise_error(Danbooru::Paginator::PaginationError, /Invalid page number/)
      end

      it "raises on values above max_numbered_pages" do
        expect { relation.paginate((Danbooru.config.max_numbered_pages + 1).to_s) }
          .to raise_error(Danbooru::Paginator::PaginationError, /cannot go beyond/)
      end

      it "raises on negative values" do
        expect { relation.paginate("-1") }.to raise_error(Danbooru::Paginator::PaginationError, /Invalid page number/)
      end

      it "raises on float strings" do
        expect { relation.paginate("10.5") }.to raise_error(Danbooru::Paginator::PaginationError, /Invalid page number/)
      end

      it "raises on non-numeric strings" do
        expect { relation.paginate("abc") }.to raise_error(Danbooru::Paginator::PaginationError, /Invalid page number/)
      end
    end

    context "with max_count specified" do
      it "caps at floor(max_count / limit) when not a multiple" do
        relation.paginate("4", limit: 10, max_count: 45)
        expect { relation.paginate("5", limit: 10, max_count: 45) }
          .to raise_error(Danbooru::Paginator::PaginationError, /cannot go beyond page 4/)
      end

      it "caps at max_count / limit when max_count is a multiple of the limit" do
        relation.paginate("5", limit: 10, max_count: 50)
        expect { relation.paginate("6", limit: 10, max_count: 50) }
          .to raise_error(Danbooru::Paginator::PaginationError, /cannot go beyond page 5/)
      end

      it "rejects all pages when max_count is smaller than the limit" do
        # max_count represents the underlying search window (from + size).
        # A single page of `limit` documents will exceed this window, so no pages should be valid.
        expect { relation.paginate("1", limit: 10, max_count: 5) }
          .to raise_error(Danbooru::Paginator::PaginationError, /cannot go beyond page 0/)
      end

      it "does not exceed Danbooru.config.max_numbered_pages" do
        relation.paginate("1", limit: 10, max_count: 1_000_000)
        expect { relation.paginate(Danbooru.config.max_numbered_pages.to_s, limit: 10, max_count: 1_000_000) }.not_to raise_error
        expect { relation.paginate((Danbooru.config.max_numbered_pages + 1).to_s, limit: 10, max_count: 1_000_000) }
          .to raise_error(Danbooru::Paginator::PaginationError, /cannot go beyond page #{Danbooru.config.max_numbered_pages}/)
      end
    end

    context "with a sequential page" do
      it "accepts b<id> and a<id> for ids in range" do
        relation.paginate("b100")
        expect(relation.current_page).to eq(100)
        expect(relation.pagination_mode).to eq(:sequential_before)

        relation.paginate("a200")
        expect(relation.current_page).to eq(200)
        expect(relation.pagination_mode).to eq(:sequential_after)
      end

      it "accepts a0 and b0" do
        expect { relation.paginate("a0") }.not_to raise_error
        expect { relation.paginate("b0") }.not_to raise_error
      end

      it "accepts the 32-bit integer max" do
        relation.paginate("a2147483647")
        expect(relation.current_page).to eq(2_147_483_647)
      end

      it "raises when the id exceeds the 32-bit integer max" do
        expect { relation.paginate("a2147483648") }
          .to raise_error(Danbooru::Paginator::PaginationError, /out of valid range/)
      end

      it "raises on negative sequential ids" do
        expect { relation.paginate("a-1") }.to raise_error(Danbooru::Paginator::PaginationError, /Invalid page number/)
      end

      it "raises on float sequential ids" do
        expect { relation.paginate("a26.5") }.to raise_error(Danbooru::Paginator::PaginationError, /Invalid page number/)
      end

      it "raises on trailing characters" do
        expect { relation.paginate("a123foo") }.to raise_error(Danbooru::Paginator::PaginationError, /Invalid page number/)
      end

      it "raises on uppercase prefixes" do
        expect { relation.paginate("A100") }.to raise_error(Danbooru::Paginator::PaginationError, /Invalid page number/)
        expect { relation.paginate("B100") }.to raise_error(Danbooru::Paginator::PaginationError, /Invalid page number/)
      end
    end
  end
end
