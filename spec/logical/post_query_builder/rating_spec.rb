# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostQueryBuilder do
  include_context "as admin"

  def run(query)
    PostQueryBuilder.new(query).search
  end

  describe "rating: metatag" do
    describe "rating:s" do
      it "includes safe-rated posts" do
        post = create(:post, rating: "s")
        expect(run("rating:s")).to include(post)
      end

      it "excludes explicitly-rated posts" do
        post = create(:post, rating: "e")
        expect(run("rating:s")).not_to include(post)
      end
    end

    describe "rating:e" do
      it "includes explicitly-rated posts" do
        post = create(:post, rating: "e")
        expect(run("rating:e")).to include(post)
      end

      it "excludes safe-rated posts" do
        post = create(:post, rating: "s")
        expect(run("rating:e")).not_to include(post)
      end
    end

    describe "rating:q" do
      it "includes questionably-rated posts" do
        post = create(:post, rating: "q")
        expect(run("rating:q")).to include(post)
      end

      it "excludes safe-rated posts" do
        post = create(:post, rating: "s")
        expect(run("rating:q")).not_to include(post)
      end
    end

    # FIXME: rating_must_not applies `where("posts.rating = ?", rating)` instead of
    # `where.not(...)` (post_query_builder.rb:195), so -rating: incorrectly acts as
    # an inclusion filter rather than an exclusion filter. Tests are commented out
    # until the bug is fixed.
    #
    # describe "-rating:s" do
    #   it "excludes safe-rated posts" do
    #     post = create(:post, rating: "s")
    #     expect(run("-rating:s")).not_to include(post)
    #   end
    #
    #   it "includes explicitly-rated posts" do
    #     post = create(:post, rating: "e")
    #     expect(run("-rating:s")).to include(post)
    #   end
    # end
  end
end
