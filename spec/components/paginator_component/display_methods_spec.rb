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

  describe "constructor mode coercion" do
    it "keeps :numbered when current_page is below max_numbered_pages" do
      c = component(mode: :numbered, current_page: 5, max_numbered_pages: 750)
      expect(c.send(:mode)).to eq(:numbered)
    end

    it "coerces :numbered to :sequential when current_page >= max_numbered_pages" do
      c = component(mode: :numbered, current_page: 750, max_numbered_pages: 750)
      expect(c.send(:mode)).to eq(:sequential)
    end

    it "leaves sequential modes unchanged" do
      %i[sequential sequential_before sequential_after].each do |m|
        c = component(mode: m)
        expect(c.send(:mode)).to eq(m)
      end
    end
  end

  describe "#display_class" do
    it "returns 'numbered' for numbered mode" do
      expect(component(mode: :numbered).send(:display_class)).to eq("numbered")
    end

    it "returns 'sequential' for sequential mode" do
      expect(component(mode: :sequential).send(:display_class)).to eq("sequential")
    end

    it "returns 'sequential' for sequential_before mode" do
      expect(component(mode: :sequential_before).send(:display_class)).to eq("sequential")
    end

    it "returns 'sequential' for sequential_after mode" do
      expect(component(mode: :sequential_after).send(:display_class)).to eq("sequential")
    end
  end

  describe "#last_page" do
    it "returns total_pages when it is below max_numbered_pages" do
      expect(component(mode: :numbered, total_pages: 20, max_numbered_pages: 750).send(:last_page)).to eq(20)
    end

    it "caps at max_numbered_pages when total_pages exceeds it" do
      expect(component(mode: :numbered, total_pages: 1000, max_numbered_pages: 750).send(:last_page)).to eq(750)
    end

    it "returns nil when total_pages is nil" do
      expect(component(mode: :numbered, total_pages: nil).send(:last_page)).to be_nil
    end

    it "always returns nil in sequential mode" do
      expect(component(mode: :sequential).send(:last_page)).to be_nil
    end
  end

  describe "#current_page" do
    it "delegates to records.current_page" do
      expect(component(current_page: 7).send(:current_page)).to eq(7)
    end
  end
end
