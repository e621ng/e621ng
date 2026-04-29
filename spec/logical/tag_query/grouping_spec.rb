# frozen_string_literal: true

require "rails_helper"

# Tests grouped query syntax: ( tag1 tag2 ), prefix dispatch (-/~), global metatag
# hoisting, is_grouped_search?, and hide_deleted_posts? interactions.
#
# Groups are stored in q[:groups][search_type] as raw group strings (when
# process_groups is not set) or as nested TagQuery objects (process_groups: true).

RSpec.describe TagQuery, type: :model do
  include_context "as member"

  describe "is_grouped_search?" do
    it "returns false for a flat query" do
      tq = TagQuery.new("tag_a tag_b", resolve_aliases: false)
      expect(tq.is_grouped_search?).to be(false)
    end

    it "returns true when the query contains a group" do
      tq = TagQuery.new("tag_c ( tag_a tag_b )", resolve_aliases: false)
      expect(tq.is_grouped_search?).to be(true)
    end
  end

  describe "group prefix dispatch" do
    it "an unmodified group is stored in q[:groups][:must]" do
      tq = TagQuery.new("tag_c ( tag_a tag_b )", resolve_aliases: false)
      expect(tq[:groups][:must]).to be_present
    end

    it "a -( group ) is stored in q[:groups][:must_not]" do
      tq = TagQuery.new("-( tag_a tag_b )", resolve_aliases: false)
      expect(tq[:groups][:must_not]).to be_present
    end

    it "a ~( group ) is stored in q[:groups][:should]" do
      tq = TagQuery.new("~( tag_a tag_b )", resolve_aliases: false)
      expect(tq[:groups][:should]).to be_present
    end
  end

  describe "group content with process_groups: true" do
    it "stores nested TagQuery objects when process_groups is true" do
      tq = TagQuery.new("tag_c ( tag_a tag_b )", process_groups: true, resolve_aliases: false)
      group = tq[:groups][:must].first
      expect(group).to be_a(TagQuery)
    end

    it "the nested TagQuery's must array contains the group's tags" do
      tq = TagQuery.new("tag_c ( tag_a tag_b )", process_groups: true, resolve_aliases: false)
      group = tq[:groups][:must].first
      expect(group[:tags][:must]).to include("tag_a", "tag_b")
    end

    it "a negated group's content has must tags inside" do
      tq = TagQuery.new("-( tag_a )", process_groups: true, resolve_aliases: false)
      group = tq[:groups][:must_not].first
      expect(group).to be_a(TagQuery)
      expect(group[:tags][:must]).to include("tag_a")
    end

    it "nested groups produce correctly nested TagQuery objects" do
      tq = TagQuery.new("top ( tag_outer ( tag_inner ) )", process_groups: true, resolve_aliases: false)
      outer_group = tq[:groups][:must].first
      expect(outer_group[:tags][:must]).to include("tag_outer")
      expect(outer_group[:groups]).to be_present
    end
  end

  describe "global metatag hoisting" do
    it "hoists order: from a group to the top level" do
      tq = TagQuery.new("( order:score tag_a )", resolve_aliases: false)
      expect(tq[:order]).to eq("score")
    end

    it "hoists randseed: from a group to the top level" do
      tq = TagQuery.new("( randseed:42 tag_a )", resolve_aliases: false)
      expect(tq[:random_seed]).to eq(42)
    end

    it "hoists -order: from a group to the top level" do
      tq = TagQuery.new("( -order:score tag_a )", resolve_aliases: false)
      expect(tq[:order]).to eq("score_asc")
    end
  end

  describe "tags at the top level alongside groups" do
    it "top-level tags are parsed into q[:tags]" do
      tq = TagQuery.new("top_tag ( group_tag )", resolve_aliases: false)
      expect(tq[:tags][:must]).to include("top_tag")
    end

    it "tags inside the group do not appear in the top-level tag arrays" do
      tq = TagQuery.new("top_tag ( group_tag )", resolve_aliases: false)
      expect(tq[:tags][:must]).not_to include("group_tag")
    end
  end

  describe "hide_deleted_posts?" do
    it "returns true by default (no status override)" do
      tq = TagQuery.new("tag_a", resolve_aliases: false)
      expect(tq.hide_deleted_posts?).to be(true)
    end

    it "returns false when status:deleted is present" do
      tq = TagQuery.new("status:deleted")
      expect(tq.hide_deleted_posts?).to be(false)
    end

    it "returns false when always_show_deleted: true is passed" do
      tq = TagQuery.new("tag_a", resolve_aliases: false)
      expect(tq.hide_deleted_posts?(always_show_deleted: true)).to be(false)
    end

    it "returns false when delreason is present (show_deleted is set)" do
      tq = TagQuery.new("delreason:spam")
      expect(tq.hide_deleted_posts?).to be(false)
    end
  end
end
