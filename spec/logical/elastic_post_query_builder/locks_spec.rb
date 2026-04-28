# frozen_string_literal: true

require "rails_helper"

RSpec.describe ElasticPostQueryBuilder do
  include_context "as member"

  def build_query(query_string, **opts)
    ElasticPostQueryBuilder.new(query_string, resolve_aliases: false, enable_safe_mode: false, **opts)
  end

  describe "locked metatag" do
    it "adds a rating_locked:true term to must for locked:rating" do
      expect(build_query("locked:rating").must).to include({ term: { rating_locked: true } })
    end

    it "adds a note_locked:true term to must for locked:note" do
      expect(build_query("locked:note").must).to include({ term: { note_locked: true } })
    end

    it "adds a status_locked:true term to must for locked:status" do
      expect(build_query("locked:status").must).to include({ term: { status_locked: true } })
    end

    # -locked:<type> goes to must (not must_not) with a false value, per the builder implementation
    it "adds a rating_locked:false term to must for -locked:rating" do
      expect(build_query("-locked:rating").must).to include({ term: { rating_locked: false } })
    end

    it "adds a note_locked:false term to must for -locked:note" do
      expect(build_query("-locked:note").must).to include({ term: { note_locked: false } })
    end

    it "adds a note_locked:true term to should for ~locked:note" do
      expect(build_query("~locked:note").should).to include({ term: { note_locked: true } })
    end

    describe "ratinglocked / notelocked / statuslocked aliases" do
      it "ratinglocked:true adds a rating_locked:true must clause" do
        expect(build_query("ratinglocked:true").must).to include({ term: { rating_locked: true } })
      end

      it "ratinglocked:false adds a rating_locked:false must clause (via must_not locked path)" do
        # ratinglocked:false → add_to_query(:must_not, :locked, :rating)
        # which adds { term: { rating_locked: false } } to must via locked_must_not handling
        expect(build_query("ratinglocked:false").must).to include({ term: { rating_locked: false } })
      end

      it "notelocked:true adds a note_locked:true must clause" do
        expect(build_query("notelocked:true").must).to include({ term: { note_locked: true } })
      end
    end
  end
end
