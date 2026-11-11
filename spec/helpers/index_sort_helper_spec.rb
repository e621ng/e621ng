# frozen_string_literal: true

require "rails_helper"

RSpec.describe IndexSortHelper do
  let(:sorts) do
    {
      id: { "id_desc" => "descending", "id_asc" => "ascending" },
      name: { "name" => "ascending", "name_desc" => "descending" },
    }
  end

  def with_query(query)
    allow(helper).to receive(:request).and_return(instance_double(ActionDispatch::Request, query_parameters: query))
  end

  describe "#current_index_order" do
    it "returns a known order" do
      with_query("search" => { "order" => "name_desc" })
      expect(helper.current_index_order(sorts, default: "id_desc")).to eq("name_desc")
    end

    it "returns the default without an order" do
      with_query({})
      expect(helper.current_index_order(sorts, default: "name")).to eq("name")
    end

    it "returns the default for an unknown order" do
      with_query("search" => { "order" => "bogus" })
      expect(helper.current_index_order(sorts, default: "name")).to eq("name")
    end

    it "returns the default when search is not a hash" do
      with_query("search" => "bogus")
      expect(helper.current_index_order(sorts, default: "name")).to eq("name")
    end

    it "maps an aliased order" do
      with_query("search" => { "order" => "created_at" })
      expect(helper.current_index_order(sorts, default: "name", aliases: { "created_at" => "id_desc" })).to eq("id_desc")
    end

    it "returns nil for an order aliased to no column" do
      with_query("search" => { "order" => "similarity" })
      expect(helper.current_index_order(sorts, default: "name", aliases: { "similarity" => nil })).to be_nil
    end

    it "returns id_desc on sequential pages, which ignore the order" do
      with_query("search" => { "order" => "name" }, "page" => "b123")
      expect(helper.current_index_order(sorts, default: "name")).to eq("id_desc")
    end
  end

  describe "#index_sort_link" do
    let(:sorts_with_single) { sorts.merge(status: { "status" => "descending" }) }

    def link_order(column, current)
      order = nil
      allow(helper).to receive(:url_for).and_call_original
      allow(helper).to receive(:url_for).with(hash_including(:params)) do |options|
        order = options[:params]["search"]["order"]
        "/index"
      end
      helper.index_sort_link(sorts_with_single, column, "Label", "classes", current: current)
      order
    end

    it "applies a column's first order while another column is sorted" do
      with_query("search" => { "order" => "name" })
      expect(link_order(:id, "name")).to eq("id_desc")
    end

    it "reverses the sorted column" do
      with_query("search" => { "order" => "id_desc" })
      expect(link_order(:id, "id_desc")).to eq("id_asc")
    end

    it "keeps the order of a sorted column with a single order" do
      with_query("search" => { "order" => "status" })
      expect(link_order(:status, "status")).to eq("status")
    end
  end
end
