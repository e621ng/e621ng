# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                    UploadWhitelist Instance Methods                         #
# --------------------------------------------------------------------------- #

RSpec.describe UploadWhitelist do
  before { CurrentUser.user = create(:moderator_user) }
  after  { CurrentUser.user = nil }

  describe "instance methods" do
    # -------------------------------------------------------------------------
    # #domain_regexp
    # -------------------------------------------------------------------------
    describe "#domain_regexp" do
      it "returns a Regexp anchored to the domain pattern" do
        entry = build(:upload_whitelist, domain: "example\\.com")
        expect(entry.domain_regexp).to eq(Regexp.new("^example\\.com$", Regexp::IGNORECASE))
      end

      it "matches a string that satisfies the domain pattern" do
        entry = build(:upload_whitelist, domain: "example\\.com")
        expect(entry.domain_regexp).to match("example.com")
      end

      it "does not match an unrelated host" do
        entry = build(:upload_whitelist, domain: "example\\.com")
        expect(entry.domain_regexp).not_to match("other.com")
      end

      it "is case-insensitive" do
        entry = build(:upload_whitelist, domain: "example\\.com")
        expect(entry.domain_regexp).to match("EXAMPLE.COM")
      end

      it "is memoized" do
        entry = build(:upload_whitelist)
        expect(entry.domain_regexp).to equal(entry.domain_regexp)
      end
    end

    # -------------------------------------------------------------------------
    # #path_regexp
    # -------------------------------------------------------------------------
    describe "#path_regexp" do
      it "returns a Regexp anchored to the path pattern" do
        entry = build(:upload_whitelist, path: "\\/images\\/.+")
        expect(entry.path_regexp).to eq(Regexp.new("^\\/images\\/.+$", Regexp::IGNORECASE))
      end

      it "matches a path that satisfies the pattern" do
        entry = build(:upload_whitelist, path: "\\/images\\/.+")
        expect(entry.path_regexp).to match("/images/photo.jpg")
      end

      it "does not match a path outside the pattern" do
        entry = build(:upload_whitelist, path: "\\/images\\/.+")
        expect(entry.path_regexp).not_to match("/files/doc.pdf")
      end

      it "is case-insensitive" do
        entry = build(:upload_whitelist, path: "\\/images\\/.+")
        expect(entry.path_regexp).to match("/IMAGES/photo.jpg")
      end

      it "is memoized" do
        entry = build(:upload_whitelist)
        expect(entry.path_regexp).to equal(entry.path_regexp)
      end
    end
  end
end
