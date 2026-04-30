# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostQueryBuilder do
  include_context "as admin"

  def run(query)
    PostQueryBuilder.new(query).search
  end

  describe "tag search" do
    describe "must tags" do
      it "includes a post whose tag_string contains the required tag" do
        post = create(:post)
        post.update_columns(tag_string: "cute fluffy")
        expect(run("cute")).to include(post)
      end

      it "excludes a post whose tag_string does not contain the required tag" do
        post = create(:post)
        post.update_columns(tag_string: "fluffy soft")
        expect(run("cute")).not_to include(post)
      end

      it "requires all must tags to be present" do
        has_both = create(:post)
        has_both.update_columns(tag_string: "cute fluffy")
        has_one = create(:post)
        has_one.update_columns(tag_string: "cute")

        result = run("cute fluffy")
        expect(result).to include(has_both)
        expect(result).not_to include(has_one)
      end
    end

    describe "must_not tags" do
      it "excludes a post that has a negated tag" do
        post = create(:post)
        post.update_columns(tag_string: "cute gross")
        expect(run("-gross")).not_to include(post)
      end

      it "includes a post that does not have the negated tag" do
        post = create(:post)
        post.update_columns(tag_string: "cute fluffy")
        expect(run("-gross")).to include(post)
      end
    end

    describe "should tags" do
      it "includes a post that has a should tag" do
        post = create(:post)
        post.update_columns(tag_string: "fluffy")
        expect(run("~fluffy")).to include(post)
      end

      it "excludes a post that has none of the should tags" do
        post = create(:post)
        post.update_columns(tag_string: "cute")
        expect(run("~fluffy ~soft")).not_to include(post)
      end

      it "includes a post that has at least one should tag" do
        post = create(:post)
        post.update_columns(tag_string: "soft")
        expect(run("~fluffy ~soft")).to include(post)
      end
    end

    describe "mixed polarities" do
      it "routes each tag to the correct filter" do
        match = create(:post)
        match.update_columns(tag_string: "cute fluffy")
        no_must = create(:post)
        no_must.update_columns(tag_string: "fluffy")
        has_excluded = create(:post)
        has_excluded.update_columns(tag_string: "cute gross")
        no_should = create(:post)
        no_should.update_columns(tag_string: "cute")

        result = run("cute -gross ~fluffy")
        expect(result).to include(match)
        expect(result).not_to include(no_must)
        expect(result).not_to include(has_excluded)
        expect(result).not_to include(no_should)
      end
    end
  end
end
