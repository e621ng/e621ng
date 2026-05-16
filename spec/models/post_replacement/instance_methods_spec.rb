# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                    PostReplacement Instance Methods                         #
# --------------------------------------------------------------------------- #

RSpec.describe PostReplacement do
  include_context "as admin"

  # --------------------------------------------------------------------------
  # #visible_to?
  # --------------------------------------------------------------------------
  describe "#visible_to?" do
    it "returns true for any user when the replacement is not rejected" do
      replacement = create(:post_replacement)
      expect(replacement.visible_to?(create(:user))).to be true
    end

    it "returns true for a janitor when the replacement is rejected" do
      replacement = create(:rejected_post_replacement)
      expect(replacement.visible_to?(create(:janitor_user))).to be true
    end

    it "returns false for a member when the replacement is rejected" do
      replacement = create(:rejected_post_replacement)
      expect(replacement.visible_to?(create(:user))).to be false
    end

    it "returns false for an anonymous user when the replacement is rejected" do
      replacement = create(:rejected_post_replacement)
      expect(replacement.visible_to?(User.anonymous)).to be false
    end
  end

  # --------------------------------------------------------------------------
  # #original_file_visible_to?
  # --------------------------------------------------------------------------
  describe "#original_file_visible_to?" do
    it "returns true for a janitor" do
      replacement = create(:post_replacement)
      expect(replacement.original_file_visible_to?(create(:janitor_user))).to be true
    end

    it "returns false for a member" do
      replacement = create(:post_replacement)
      expect(replacement.original_file_visible_to?(create(:user))).to be false
    end
  end

  # --------------------------------------------------------------------------
  # #upload_as_pending?
  # --------------------------------------------------------------------------
  describe "#upload_as_pending?" do
    it "returns true when as_pending is '1'" do
      replacement = build(:post_replacement)
      replacement.as_pending = "1"
      expect(replacement.upload_as_pending?).to be true
    end

    it "returns true when as_pending is 'true'" do
      replacement = build(:post_replacement)
      replacement.as_pending = "true"
      expect(replacement.upload_as_pending?).to be true
    end

    it "returns false when as_pending is nil" do
      replacement = build(:post_replacement)
      replacement.as_pending = nil
      expect(replacement.upload_as_pending?).to be false
    end

    it "returns false when as_pending is '0'" do
      replacement = build(:post_replacement)
      replacement.as_pending = "0"
      expect(replacement.upload_as_pending?).to be false
    end

    it "defaults as_silent to false when as_pending is true" do
      replacement = build(:post_replacement)
      replacement.as_pending = "1"
      expect(replacement.upload_as_silent?).to be false
    end
  end

  describe "#upload_as_silent?" do
    it "returns true when 'as_silent' is '1'" do
      replacement = build(:post_replacement)
      replacement.as_silent = "1"
      expect(replacement.upload_as_silent?).to be true
    end

    it "returns true when 'as_silent' is 'true'" do
      replacement = build(:post_replacement)
      replacement.as_silent = "true"
      expect(replacement.upload_as_silent?).to be true
    end

    it "returns false when 'as_silent' is '0'" do
      replacement = build(:post_replacement)
      replacement.as_silent = "0"
      expect(replacement.upload_as_silent?).to be false
    end

    it "returns false when 'as_silent' is 'false'" do
      replacement = build(:post_replacement)
      replacement.as_silent = "false"
      expect(replacement.upload_as_silent?).to be false
    end

    it "returns false when 'as_silent' is nil" do
      replacement = build(:post_replacement)
      replacement.as_silent = nil
      expect(replacement.upload_as_silent?).to be false
    end
  end

  # --------------------------------------------------------------------------
  # #sequence_number
  # --------------------------------------------------------------------------
  describe "#sequence_number" do
    it "returns 0 for an original-status replacement" do
      replacement = create(:original_post_replacement)
      expect(replacement.sequence_number).to eq(0)
    end

    it "returns 1 for the first non-original replacement on a post" do
      post = create(:post)
      replacement = create(:post_replacement, post: post)
      expect(replacement.sequence_number).to eq(1)
    end

    it "returns 2 for the second non-original replacement on the same post" do
      post = create(:post)
      create(:post_replacement, post: post)
      second = create(:post_replacement, post: post)
      expect(second.sequence_number).to eq(2)
    end
  end

  # --------------------------------------------------------------------------
  # #source_list
  # --------------------------------------------------------------------------
  describe "#source_list" do
    it "returns an empty array when source is blank" do
      replacement = build(:post_replacement, source: "")
      expect(replacement.source_list).to eq([])
    end

    it "splits source on newlines" do
      replacement = build(:post_replacement, source: "https://a.com\nhttps://b.com")
      expect(replacement.source_list).to eq(["https://a.com", "https://b.com"])
    end

    it "removes blank lines" do
      replacement = build(:post_replacement, source: "https://a.com\n\nhttps://b.com")
      expect(replacement.source_list).to eq(["https://a.com", "https://b.com"])
    end

    it "deduplicates repeated entries" do
      replacement = build(:post_replacement, source: "https://a.com\nhttps://a.com")
      expect(replacement.source_list).to eq(["https://a.com"])
    end
  end

  # --------------------------------------------------------------------------
  # #replacement_url_parsed
  # --------------------------------------------------------------------------
  describe "#replacement_url_parsed" do
    it "returns nil when replacement_url is blank" do
      replacement = build(:post_replacement)
      replacement.replacement_url = nil
      expect(replacement.replacement_url_parsed).to be_nil
    end

    it "returns nil when replacement_url does not start with http(s)" do
      replacement = build(:post_replacement)
      replacement.replacement_url = "ftp://example.com/image.jpg"
      expect(replacement.replacement_url_parsed).to be_nil
    end

    it "returns a parsed URI for a valid HTTP URL" do
      replacement = build(:post_replacement)
      replacement.replacement_url = "https://example.com/image.jpg"
      parsed = replacement.replacement_url_parsed
      expect(parsed).to be_a(Addressable::URI)
      expect(parsed.host).to eq("example.com")
    end
  end

  # --------------------------------------------------------------------------
  # #promoted_id
  # --------------------------------------------------------------------------
  describe "#promoted_id" do
    it "returns nil when status is not 'promoted'" do
      replacement = create(:post_replacement, status: "pending")
      expect(replacement.promoted_id).to be_nil
    end

    it "returns the id of a post found by md5 when the replacement is promoted" do
      promoted_post = create(:post)
      replacement = create(:promoted_post_replacement, md5: promoted_post.md5)
      expect(replacement.promoted_id).to eq(promoted_post.id)
    end
  end
end
