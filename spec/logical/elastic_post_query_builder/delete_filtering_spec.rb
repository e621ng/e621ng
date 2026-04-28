# frozen_string_literal: true

require "rails_helper"

RSpec.describe ElasticPostQueryBuilder do
  include_context "as member"

  def build_query(query_string, **opts)
    ElasticPostQueryBuilder.new(query_string, resolve_aliases: false, enable_safe_mode: false, **opts)
  end

  describe "delete filtering" do
    it "injects deleted:false into must for a plain query with no status metatag" do
      expect(build_query("cute").must).to include({ term: { deleted: false } })
    end

    it "does not inject deleted:false when status:deleted is present" do
      expect(build_query("status:deleted").must).not_to include({ term: { deleted: false } })
    end

    it "does not inject deleted:false when status:all is present" do
      expect(build_query("status:all").must).not_to include({ term: { deleted: false } })
    end

    it "does not inject deleted:false when status:any is present" do
      expect(build_query("status:any").must).not_to include({ term: { deleted: false } })
    end

    # show_deleted is not a query-string metatag; it is set internally by status parsing.
    # status:deleted / status:all / status:any all cause show_deleted to be set true.

    it "does not inject deleted:false when always_show_deleted: true is passed as constructor option" do
      expect(build_query("cute", always_show_deleted: true).must).not_to include({ term: { deleted: false } })
    end

    it "injects deleted:false for status:pending (not an override status value)" do
      expect(build_query("status:pending").must).to include({ term: { deleted: false } })
    end

    it "injects deleted:false for status:flagged (not an override status value)" do
      expect(build_query("status:flagged").must).to include({ term: { deleted: false } })
    end

    it "injects deleted:false for status:modqueue (not an override status value)" do
      expect(build_query("status:modqueue").must).to include({ term: { deleted: false } })
    end
  end

  describe "#hide_deleted_posts?" do
    it "returns true for a plain query (deleted posts should be hidden)" do
      builder = build_query("cute")
      expect(builder.hide_deleted_posts?).to be(true)
    end

    it "returns false when show_deleted is set (via status:deleted)" do
      builder = build_query("status:deleted")
      expect(builder.hide_deleted_posts?).to be(false)
    end

    it "returns false when always_show_deleted: true is passed" do
      builder = build_query("cute", always_show_deleted: true)
      expect(builder.hide_deleted_posts?).to be(false)
    end
  end

  describe "#innate_hide_deleted_posts?" do
    it "returns true for a plain query" do
      builder = build_query("cute")
      expect(builder.innate_hide_deleted_posts?).to be(true)
    end

    it "returns false when show_deleted is set (via status:deleted)" do
      builder = build_query("status:deleted")
      expect(builder.innate_hide_deleted_posts?).to be(false)
    end

    it "returns true regardless of always_show_deleted constructor option" do
      # innate_hide_deleted_posts? ignores @always_show_deleted
      builder = build_query("cute", always_show_deleted: true)
      expect(builder.innate_hide_deleted_posts?).to be(true)
    end
  end
end
