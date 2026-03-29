# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        PostDisapproval.search                               #
# --------------------------------------------------------------------------- #

RSpec.describe PostDisapproval do
  let(:member) { create(:user) }

  before do
    CurrentUser.user    = member
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  def make_disapproval(overrides = {})
    create(:post_disapproval, **overrides)
  end

  describe ".search" do
    # -------------------------------------------------------------------------
    # creator filter (where_user on :user_id)
    # -------------------------------------------------------------------------
    describe "creator filter" do
      let(:other_user) { create(:user) }
      let!(:own)   { make_disapproval(user: member) }
      let!(:other) { make_disapproval(user: other_user) }

      it "filters by creator_name" do
        results = PostDisapproval.search(creator_name: member.name)
        expect(results).to include(own)
        expect(results).not_to include(other)
      end

      it "filters by creator_id" do
        results = PostDisapproval.search(creator_id: member.id)
        expect(results).to include(own)
        expect(results).not_to include(other)
      end
    end

    # -------------------------------------------------------------------------
    # post_id filter
    # -------------------------------------------------------------------------
    describe "post_id filter" do
      let(:post_a) { create(:post) }
      let(:post_b) { create(:post) }
      let!(:for_a) { make_disapproval(post: post_a) }
      let!(:for_b) { make_disapproval(post: post_b) }

      # FIXME: attribute_matches delegates to numeric_attribute_matches, which
      # calls ParseValue.range. ParseValue.range calls start_with? on its
      # argument, but that method only exists on String — passing an Integer
      # raises NoMethodError: undefined method `start_with?' for an instance
      # of Integer. Pass the id as a string until the bug in parse_value.rb
      # is fixed.
      it "returns only the disapproval for the given post_id" do
        results = PostDisapproval.search(post_id: post_a.id.to_s)
        expect(results).to include(for_a)
        expect(results).not_to include(for_b)
      end
    end

    # -------------------------------------------------------------------------
    # message filter
    # -------------------------------------------------------------------------
    describe "message filter" do
      let!(:matching)    { make_disapproval(message: "needs improvement here") }
      let!(:nonmatching) { make_disapproval(message: "unrelated") }

      it "returns records whose message matches the wildcard pattern" do
        results = PostDisapproval.search(message: "*improvement*")
        expect(results).to include(matching)
        expect(results).not_to include(nonmatching)
      end

      it "returns all records when message param is absent" do
        results = PostDisapproval.search({})
        expect(results).to include(matching, nonmatching)
      end
    end

    # -------------------------------------------------------------------------
    # reason filter
    # -------------------------------------------------------------------------
    describe "reason filter" do
      let!(:quality)   { make_disapproval(reason: "borderline_quality") }
      let!(:relevancy) { make_disapproval(reason: "borderline_relevancy") }
      let!(:other)     { make_disapproval(reason: "other") }

      it "returns only records with the given reason" do
        results = PostDisapproval.search(reason: "borderline_quality")
        expect(results).to include(quality)
        expect(results).not_to include(relevancy, other)
      end

      it "returns all records when reason param is absent" do
        results = PostDisapproval.search({})
        expect(results).to include(quality, relevancy, other)
      end
    end

    # -------------------------------------------------------------------------
    # has_message filter
    # -------------------------------------------------------------------------
    describe "has_message filter" do
      let!(:with_msg)    { make_disapproval(message: "some comment") }
      let!(:without_msg) { make_disapproval(message: nil) }

      it "returns only records with a message when has_message is truthy" do
        results = PostDisapproval.search(has_message: "true")
        expect(results).to include(with_msg)
        expect(results).not_to include(without_msg)
      end

      it "returns only records without a message when has_message is falsy" do
        results = PostDisapproval.search(has_message: "false")
        expect(results).to include(without_msg)
        expect(results).not_to include(with_msg)
      end

      it "returns all records when has_message is absent" do
        results = PostDisapproval.search({})
        expect(results).to include(with_msg, without_msg)
      end
    end

    # -------------------------------------------------------------------------
    # post_tags_match filter
    # -------------------------------------------------------------------------
    describe "post_tags_match filter" do
      let(:tagged_post)   { create(:post, tag_string: "tagme special_tag") }
      let(:untagged_post) { create(:post, tag_string: "tagme") }
      let!(:tagged_disapproval)   { make_disapproval(post: tagged_post) }
      let!(:untagged_disapproval) { make_disapproval(post: untagged_post) }

      it "returns only disapprovals whose post matches the tag query" do
        results = PostDisapproval.search(post_tags_match: "special_tag")
        expect(results).to include(tagged_disapproval)
        expect(results).not_to include(untagged_disapproval)
      end
    end

    # -------------------------------------------------------------------------
    # order parameter
    # -------------------------------------------------------------------------
    describe "order parameter" do
      let(:post_a) { create(:post) }
      let(:post_b) { create(:post) }
      let!(:first)  { make_disapproval(post: post_a) }
      let!(:second) { make_disapproval(post: post_b) }

      it "orders by post_id descending when order is 'post_id_desc'" do
        # Ensure distinct post ids by using explicit posts above
        results = PostDisapproval.search(order: "post_id_desc")
        ids = results.map(&:post_id)
        expect(ids).to eq(ids.sort.reverse)
      end

      it "orders by post_id descending when order is 'post_id'" do
        results = PostDisapproval.search(order: "post_id")
        ids = results.map(&:post_id)
        expect(ids).to eq(ids.sort.reverse)
      end

      it "returns records newest-first by default (apply_basic_order)" do
        ids = PostDisapproval.search({}).ids
        expect(ids.index(second.id)).to be < ids.index(first.id)
      end

      it "returns records oldest-first when order is 'id_asc'" do
        ids = PostDisapproval.search(order: "id_asc").ids
        expect(ids.index(first.id)).to be < ids.index(second.id)
      end
    end
  end
end
