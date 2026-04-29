# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          PostApproval.search                                #
# --------------------------------------------------------------------------- #

RSpec.describe PostApproval do
  let(:member) { create(:user) }

  before do
    CurrentUser.user    = member
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  def make_approval(overrides = {})
    create(:post_approval, **overrides)
  end

  describe ".search" do
    # -------------------------------------------------------------------------
    # user filter (where_user on :user_id)
    # -------------------------------------------------------------------------
    describe "user filter" do
      let(:other_user) { create(:user) }
      let!(:own)   { make_approval(user: member) }
      let!(:other) { make_approval(user: other_user) }

      it "filters by user_name" do
        results = PostApproval.search(user_name: member.name)
        expect(results).to include(own)
        expect(results).not_to include(other)
      end

      it "filters by user_id" do
        results = PostApproval.search(user_id: member.id)
        expect(results).to include(own)
        expect(results).not_to include(other)
      end
    end

    # -------------------------------------------------------------------------
    # post_id filter
    # -------------------------------------------------------------------------
    describe "post_id filter" do
      let(:post_a) { create(:pending_post) }
      let(:post_b) { create(:pending_post) }
      let!(:for_a) { make_approval(post: post_a) }
      let!(:for_b) { make_approval(post: post_b) }

      # FIXME: attribute_matches delegates to numeric_attribute_matches, which
      # calls ParseValue.range. ParseValue.range calls start_with? on its
      # argument, but that method only exists on String — passing an Integer
      # raises NoMethodError: undefined method `start_with?' for an instance
      # of Integer. Pass the id as a string until the bug in parse_value.rb
      # is fixed.
      it "returns only the approval for the given post_id" do
        results = PostApproval.search(post_id: post_a.id.to_s)
        expect(results).to include(for_a)
        expect(results).not_to include(for_b)
      end
    end

    # -------------------------------------------------------------------------
    # post_tags_match filter
    # -------------------------------------------------------------------------
    describe "post_tags_match filter" do
      let(:tagged_post)   { create(:pending_post, tag_string: "special_tag tagme") }
      let(:untagged_post) { create(:pending_post, tag_string: "tagme") }
      let!(:tagged_approval)   { make_approval(post: tagged_post) }
      let!(:untagged_approval) { make_approval(post: untagged_post) }

      it "returns only approvals whose post matches the tag query" do
        results = PostApproval.search(post_tags_match: "special_tag")
        expect(results).to include(tagged_approval)
        expect(results).not_to include(untagged_approval)
      end
    end

    # -------------------------------------------------------------------------
    # default ordering
    # -------------------------------------------------------------------------
    describe "default ordering" do
      let(:post_a) { create(:pending_post) }
      let(:post_b) { create(:pending_post) }
      let!(:first)  { make_approval(post: post_a) }
      let!(:second) { make_approval(post: post_b) }

      it "returns records newest-first by default" do
        ids = PostApproval.search({}).ids
        expect(ids.index(second.id)).to be < ids.index(first.id)
      end

      it "returns records oldest-first when order is 'id_asc'" do
        ids = PostApproval.search(order: "id_asc").ids
        expect(ids.index(first.id)).to be < ids.index(second.id)
      end
    end
  end
end
