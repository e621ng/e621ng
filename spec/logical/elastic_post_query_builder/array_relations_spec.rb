# frozen_string_literal: true

require "rails_helper"

RSpec.describe ElasticPostQueryBuilder do
  include_context "as member"

  def build_query(query_string, **opts)
    ElasticPostQueryBuilder.new(query_string, resolve_aliases: false, enable_safe_mode: false, **opts)
  end

  describe "array relation metatags" do
    describe "user_id (uploader)" do
      it "adds a term clause for user_id:1 (no DB lookup needed for numeric IDs)" do
        expect(build_query("user_id:1").must).to include({ term: { uploader: 1 } })
      end

      it "adds a must_not term clause for -user_id:1" do
        expect(build_query("-user_id:1").must_not).to include({ term: { uploader: 1 } })
      end

      it "adds a should term clause for ~user_id:1" do
        expect(build_query("~user_id:1").should).to include({ term: { uploader: 1 } })
      end
    end

    describe "rating" do
      it "adds a term clause for rating:s" do
        expect(build_query("rating:s").must).to include({ term: { rating: "s" } })
      end

      it "adds a must_not term clause for -rating:s" do
        expect(build_query("-rating:s").must_not).to include({ term: { rating: "s" } })
      end
    end

    describe "filetype" do
      it "adds a term clause for filetype:png" do
        expect(build_query("filetype:png").must).to include({ term: { file_ext: "png" } })
      end

      it "adds a must_not term clause for -filetype:jpg" do
        expect(build_query("-filetype:jpg").must_not).to include({ term: { file_ext: "jpg" } })
      end
    end

    describe "source (wildcard)" do
      it "adds a wildcard clause for source:*example.com*" do
        expect(build_query("source:*example.com*").must).to include({ wildcard: { source: "*example.com*" } })
      end

      it "adds a must_not wildcard clause for -source:*example.com*" do
        expect(build_query("-source:*example.com*").must_not).to include({ wildcard: { source: "*example.com*" } })
      end
    end

    describe "description (match_phrase_prefix)" do
      it "adds a match_phrase_prefix clause for description:hello" do
        expect(build_query("description:hello").must).to include({ match_phrase_prefix: { description: "hello" } })
      end
    end

    describe "note (match_phrase_prefix)" do
      it "adds a match_phrase_prefix clause for note:text" do
        expect(build_query("note:text").must).to include({ match_phrase_prefix: { notes: "text" } })
      end
    end

    describe "delreason (wildcard)" do
      it "adds a wildcard clause for delreason:spam" do
        expect(build_query("delreason:spam").must).to include({ wildcard: { del_reason: "spam" } })
      end
    end

    describe "pool any/none" do
      it "adds an exists clause to must for pool:any" do
        expect(build_query("pool:any").must).to include({ exists: { field: :pools } })
      end

      it "adds an exists clause to must_not for pool:none" do
        expect(build_query("pool:none").must_not).to include({ exists: { field: :pools } })
      end
    end

    describe "parent any/none" do
      it "adds an exists clause to must for parent:any" do
        expect(build_query("parent:any").must).to include({ exists: { field: :parent } })
      end

      it "adds an exists clause to must_not for parent:none" do
        expect(build_query("parent:none").must_not).to include({ exists: { field: :parent } })
      end
    end

    describe "approver any/none" do
      it "adds an exists clause to must for approver:any" do
        expect(build_query("approver:any").must).to include({ exists: { field: :approver } })
      end

      it "adds an exists clause to must_not for approver:none" do
        expect(build_query("approver:none").must_not).to include({ exists: { field: :approver } })
      end

      it "negates 'any' to 'none' for -approver:any" do
        # -approver:any means "approver must not be any" i.e. approver:none
        expect(build_query("-approver:any").must_not).to include({ exists: { field: :approver } })
      end
    end

    describe "commenter any/none" do
      it "adds an exists clause to must for commenter:any" do
        expect(build_query("commenter:any").must).to include({ exists: { field: :commenters } })
      end

      it "adds an exists clause to must_not for commenter:none" do
        expect(build_query("commenter:none").must_not).to include({ exists: { field: :commenters } })
      end
    end

    describe "noter any/none" do
      it "adds an exists clause to must for noter:any" do
        expect(build_query("noter:any").must).to include({ exists: { field: :noters } })
      end
    end

    describe "source any/none" do
      it "adds an exists clause to must for source:any" do
        expect(build_query("source:any").must).to include({ exists: { field: :source } })
      end

      it "adds an exists clause to must_not for source:none" do
        expect(build_query("source:none").must_not).to include({ exists: { field: :source } })
      end
    end
  end
end
