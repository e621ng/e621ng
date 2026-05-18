# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           Upload Callbacks                                  #
# --------------------------------------------------------------------------- #

RSpec.describe Upload do
  describe "callbacks" do
    # -------------------------------------------------------------------------
    # before_validation :assign_rating_from_tags
    # -------------------------------------------------------------------------
    describe "before_validation :assign_rating_from_tags" do
      it "sets rating to 's' when tag_string contains 'rating:s'" do
        upload = build(:upload, tag_string: "rating:s cat", rating: "e")
        upload.valid?
        expect(upload.rating).to eq("s")
      end

      it "uses only the first character of the rating value" do
        upload = build(:upload, tag_string: "rating:explicit cat", rating: "s")
        upload.valid?
        expect(upload.rating).to eq("e")
      end

      it "sets rating to 'q' when tag_string contains 'rating:questionable'" do
        upload = build(:upload, tag_string: "rating:questionable", rating: "s")
        upload.valid?
        expect(upload.rating).to eq("q")
      end

      it "leaves rating unchanged when tag_string contains no rating metatag" do
        upload = build(:upload, tag_string: "safe_cat fluffy", rating: "e")
        upload.valid?
        expect(upload.rating).to eq("e")
      end
    end

    # -------------------------------------------------------------------------
    # before_validation :fixup_source, on: :create
    # -------------------------------------------------------------------------
    describe "before_validation :fixup_source, on: :create" do
      it "sets source to empty string when source is nil" do
        upload = build(:upload, source: nil)
        upload.valid?
        expect(upload.source).to eq("")
      end

      it "leaves source unchanged when source is already set and no direct_url" do
        upload = build(:upload, source: "https://original.example.com/image", direct_url: nil)
        upload.valid?
        expect(upload.source).to eq("https://original.example.com/image")
      end

      context "when direct_url resolves to a canonical URL" do
        before { CurrentUser.user = create(:moderator_user) }
        after  { CurrentUser.user = nil }

        it "appends the canonical URL to source" do
          create(:upload_whitelist, domain: "example\\.com", path: "\\/.+")
          canonical = "https://example.com/canonical/image.jpg"
          allow(Sources::Strategies).to receive(:find)
            .and_return(instance_double(Sources::Strategies::Base, canonical_url: canonical))

          upload = build(:upload, direct_url: "https://example.com/image", source: "original")
          upload.valid?
          expect(upload.source).to include(canonical)
        end

        it "does not append anything when canonical_url is nil" do
          create(:upload_whitelist, domain: "example\\.com", path: "\\/.+")
          allow(Sources::Strategies).to receive(:find)
            .and_return(instance_double(Sources::Strategies::Base, canonical_url: nil))

          upload = build(:upload, direct_url: "https://example.com/image", source: "original")
          upload.valid?
          expect(upload.source).to eq("original")
        end
      end
    end
  end
end
