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

    it "returns id_desc on sequential pages, which ignore the order" do
      with_query("search" => { "order" => "name" }, "page" => "b123")
      expect(helper.current_index_order(sorts, default: "name")).to eq("id_desc")
    end
  end
end
