# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostQueryBuilder do
  include_context "as admin"

  def run(query)
    PostQueryBuilder.new(query).search
  end

  describe "pool: metatag" do
    describe "pool:none" do
      it "includes posts with an empty pool_string" do
        post = create(:post)
        post.update_columns(pool_string: "")
        expect(run("pool:none")).to include(post)
      end

      it "excludes posts that belong to a pool" do
        post = create(:post)
        post.update_columns(pool_string: "pool:1")
        expect(run("pool:none")).not_to include(post)
      end
    end

    describe "pool:any" do
      it "includes posts that belong to at least one pool" do
        post = create(:post)
        post.update_columns(pool_string: "pool:1")
        expect(run("pool:any")).to include(post)
      end

      it "excludes posts with an empty pool_string" do
        post = create(:post)
        post.update_columns(pool_string: "")
        expect(run("pool:any")).not_to include(post)
      end
    end

    describe "inpool:true" do
      it "includes posts that belong to at least one pool" do
        post = create(:post)
        post.update_columns(pool_string: "pool:1")
        expect(run("inpool:true")).to include(post)
      end

      it "excludes posts with an empty pool_string" do
        post = create(:post)
        post.update_columns(pool_string: "")
        expect(run("inpool:true")).not_to include(post)
      end
    end

    describe "inpool:false" do
      it "includes posts with an empty pool_string" do
        post = create(:post)
        post.update_columns(pool_string: "")
        expect(run("inpool:false")).to include(post)
      end

      it "excludes posts that belong to a pool" do
        post = create(:post)
        post.update_columns(pool_string: "pool:1")
        expect(run("inpool:false")).not_to include(post)
      end
    end
  end
end
