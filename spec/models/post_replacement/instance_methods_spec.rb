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

  # --------------------------------------------------------------------------
  # #increment_user_replacement_count
  # --------------------------------------------------------------------------
  describe "#increment_user_replacement_count" do
    let(:user_status_relation) { instance_double(ActiveRecord::Relation) }

    before do
      allow(CurrentUser).to receive(:id).and_return(123)
      allow(UserStatus).to receive(:for_user).with(123).and_return(user_status_relation)
      allow(user_status_relation).to receive(:update_all)
    end

    it "increments UserStatus item 'post_replacement_submitted_count'" do
      post_replacement = build(:post_replacement, status: "pending")

      post_replacement.increment_user_replacement_count

      expect(UserStatus).to have_received(:for_user).with(123)
      expect(user_status_relation).to have_received(:update_all)
    end

    it "is called on create of pending" do
      post_replacement = build(:post_replacement, status: "pending")

      # Skip validations so we don't trigger external URL fetching during callback tests
      post_replacement.save(validate: false)

      expect(user_status_relation).to have_received(:update_all).once
    end

    it "is not called on create of original" do
      post_replacement = build(:post_replacement, status: "original")

      post_replacement.save(validate: false)

      expect(UserStatus).not_to have_received(:for_user)
      expect(user_status_relation).not_to have_received(:update_all)
    end
  end

  # --------------------------------------------------------------------------
  # #decrement_user_replacement_count
  # --------------------------------------------------------------------------
  describe "#decrement_user_replacement_count" do
    let(:user_status_relation) { instance_double(ActiveRecord::Relation) }

    before do
      allow(CurrentUser).to receive(:id).and_return(123)
      allow(UserStatus).to receive(:for_user).with(123).and_return(user_status_relation)
      allow(user_status_relation).to receive(:update_all)
    end

    it "decrements UserStatus item 'post_replacement_submitted_count'" do
      post_replacement = build(:post_replacement, status: "pending")

      post_replacement.decrement_user_replacement_count

      expect(UserStatus).to have_received(:for_user).with(123)
      expect(user_status_relation).to have_received(:update_all)
    end

    it "is called on destroy of non-original" do
      post_replacement = build(:post_replacement, status: "pending")

      # Prevent the creation callback from hitting update_all
      allow(post_replacement).to receive(:decrement_user_replacement_count)
      post_replacement.save(validate: false)

      post_replacement.destroy!

      expect(user_status_relation).to have_received(:update_all).once
    end

    it "is not called on destroy of original" do
      post_replacement = build(:post_replacement, status: "original")
      post_replacement.save(validate: false)

      post_replacement.destroy!

      expect(user_status_relation).not_to have_received(:update_all)
    end
  end
end
