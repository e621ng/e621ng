# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           Upload Search                                     #
# --------------------------------------------------------------------------- #

RSpec.describe Upload do
  def make_upload(overrides = {})
    create(:upload, **overrides)
  end

  # -------------------------------------------------------------------------
  # .pending scope
  # -------------------------------------------------------------------------
  describe ".pending" do
    let!(:pending_upload)   { make_upload(status: "pending") }
    let!(:completed_upload) { make_upload(status: "completed") }

    it "returns uploads with status 'pending'" do
      expect(Upload.pending).to include(pending_upload)
    end

    it "excludes uploads with other statuses" do
      expect(Upload.pending).not_to include(completed_upload)
    end
  end

  # -------------------------------------------------------------------------
  # .search
  # -------------------------------------------------------------------------
  describe ".search" do
    # -------------------------------------------------------------------------
    # source (exact match)
    # -------------------------------------------------------------------------
    describe "source parameter" do
      let!(:matching)    { make_upload(source: "https://example.com/image.jpg") }
      let!(:nonmatching) { make_upload(source: "https://other.com/image.jpg") }

      it "returns uploads whose source exactly matches" do
        results = Upload.search(source: "https://example.com/image.jpg")
        expect(results).to include(matching)
        expect(results).not_to include(nonmatching)
      end

      it "returns all uploads when source is absent" do
        results = Upload.search({})
        expect(results).to include(matching, nonmatching)
      end
    end

    # -------------------------------------------------------------------------
    # source_matches (wildcard LIKE)
    # -------------------------------------------------------------------------
    describe "source_matches parameter" do
      let!(:matching)    { make_upload(source: "https://example.com/image.jpg") }
      let!(:nonmatching) { make_upload(source: "https://other.com/photo.png") }

      it "returns uploads whose source matches the wildcard pattern" do
        results = Upload.search(source_matches: "*example.com*")
        expect(results).to include(matching)
        expect(results).not_to include(nonmatching)
      end
    end

    # -------------------------------------------------------------------------
    # rating (exact match)
    # -------------------------------------------------------------------------
    describe "rating parameter" do
      let!(:explicit)     { make_upload(rating: "e") }
      let!(:safe)         { make_upload(rating: "s") }

      it "returns only uploads with the given rating" do
        results = Upload.search(rating: "e")
        expect(results).to include(explicit)
        expect(results).not_to include(safe)
      end
    end

    # -------------------------------------------------------------------------
    # status (LIKE match)
    # -------------------------------------------------------------------------
    describe "status parameter" do
      let!(:pending_upload)  { make_upload(status: "pending") }
      let!(:errored_upload)  { make_upload(status: "error: bad file") }

      it "returns uploads whose status matches the pattern" do
        results = Upload.search(status: "error*")
        expect(results).to include(errored_upload)
        expect(results).not_to include(pending_upload)
      end
    end

    # -------------------------------------------------------------------------
    # tag_string (LIKE match)
    # -------------------------------------------------------------------------
    describe "tag_string parameter" do
      let!(:tagged)   { make_upload(tag_string: "artist:someone fluffy_tail") }
      let!(:untagged) { make_upload(tag_string: "") }

      it "returns uploads whose tag_string matches the pattern" do
        results = Upload.search(tag_string: "*fluffy*")
        expect(results).to include(tagged)
        expect(results).not_to include(untagged)
      end
    end

    # -------------------------------------------------------------------------
    # backtrace (LIKE match)
    # -------------------------------------------------------------------------
    describe "backtrace parameter" do
      let!(:with_trace)    { make_upload(backtrace: "RuntimeError: something broke\n  app/models/upload.rb:42") }
      let!(:without_trace) { make_upload(backtrace: nil) }

      it "returns uploads whose backtrace matches the pattern" do
        results = Upload.search(backtrace: "*RuntimeError*")
        expect(results).to include(with_trace)
        expect(results).not_to include(without_trace)
      end
    end
  end
end
