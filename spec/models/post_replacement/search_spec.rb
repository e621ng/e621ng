# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       PostReplacement Search                                #
# --------------------------------------------------------------------------- #

RSpec.describe PostReplacement do
  include_context "as admin"

  def make_replacement(overrides = {})
    create(:post_replacement, **overrides)
  end

  # --------------------------------------------------------------------------
  # file_ext
  # --------------------------------------------------------------------------
  describe "file_ext param" do
    let!(:jpg) { make_replacement(file_ext: "jpg") }
    let!(:png) { make_replacement(file_ext: "png") }

    it "returns only records matching the given extension" do
      results = PostReplacement.search(file_ext: "jpg")
      expect(results).to include(jpg)
      expect(results).not_to include(png)
    end
  end

  # --------------------------------------------------------------------------
  # md5
  # --------------------------------------------------------------------------
  describe "md5 param" do
    let!(:target) { make_replacement(md5: "aabbccddeeff00112233445566778899") }
    let!(:other)  { make_replacement }

    it "returns only the record with the matching md5" do
      results = PostReplacement.search(md5: "aabbccddeeff00112233445566778899")
      expect(results).to include(target)
      expect(results).not_to include(other)
    end
  end

  # --------------------------------------------------------------------------
  # status
  # --------------------------------------------------------------------------
  describe "status param" do
    let!(:pending)  { make_replacement(status: "pending") }
    let!(:rejected) { create(:rejected_post_replacement) }

    it "returns only records with the matching status" do
      results = PostReplacement.search(status: "pending")
      expect(results).to include(pending)
      expect(results).not_to include(rejected)
    end
  end

  # --------------------------------------------------------------------------
  # post_id
  # --------------------------------------------------------------------------
  describe "post_id param" do
    let!(:post_a) { create(:post) }
    let!(:post_b) { create(:post) }
    let!(:repl_a) { make_replacement(post: post_a) }
    let!(:repl_b) { make_replacement(post: post_b) }
    let!(:repl_c) { make_replacement }

    it "returns replacements for any of the given comma-separated post ids" do
      results = PostReplacement.search(post_id: "#{post_a.id},#{post_b.id}")
      expect(results).to include(repl_a, repl_b)
      expect(results).not_to include(repl_c)
    end
  end

  # --------------------------------------------------------------------------
  # reason
  # --------------------------------------------------------------------------
  describe "reason param" do
    let!(:target) { make_replacement(reason: "Very specific reason text") }
    let!(:other)  { make_replacement(reason: "Something entirely different") }

    it "matches reasons by wildcard" do
      results = PostReplacement.search(reason: "*specific reason*")
      expect(results).to include(target)
      expect(results).not_to include(other)
    end
  end

  # --------------------------------------------------------------------------
  # penalized
  # --------------------------------------------------------------------------
  describe "penalized param" do
    let!(:penalized) do
      create(:approved_post_replacement).tap { |r| r.update_columns(penalize_uploader_on_approve: true) }
    end
    let!(:not_penalized) do
      create(:approved_post_replacement).tap { |r| r.update_columns(penalize_uploader_on_approve: false) }
    end

    it "returns penalized records when param is truthy" do
      results = PostReplacement.search(penalized: "true")
      expect(results).to include(penalized)
      expect(results).not_to include(not_penalized)
    end

    it "returns non-penalized records when param is falsy" do
      results = PostReplacement.search(penalized: "false")
      expect(results).to include(not_penalized)
      expect(results).not_to include(penalized)
    end
  end

  # --------------------------------------------------------------------------
  # source  (auto-wildcarded: "example.com" → "*example.com*")
  # --------------------------------------------------------------------------
  describe "source param" do
    let!(:target) { make_replacement(source: "https://example.com/image.jpg") }
    let!(:other)  { make_replacement(source: "https://other-site.net/img.png") }

    it "matches when the source contains the search string" do
      results = PostReplacement.search(source: "example.com")
      expect(results).to include(target)
      expect(results).not_to include(other)
    end
  end

  # --------------------------------------------------------------------------
  # file_name
  # --------------------------------------------------------------------------
  describe "file_name param" do
    let!(:target) { make_replacement(file_name: "uniquefilename.jpg") }
    let!(:other)  { make_replacement(file_name: "anotherfile.png") }

    it "matches by wildcard" do
      results = PostReplacement.search(file_name: "*uniquefilename*")
      expect(results).to include(target)
      expect(results).not_to include(other)
    end
  end

  # --------------------------------------------------------------------------
  # creator_id (where_user)
  # --------------------------------------------------------------------------
  describe "creator_id param" do
    let!(:creator_a) { create(:user) }
    let!(:creator_b) { create(:user) }
    let!(:repl_a)    { make_replacement(creator: creator_a) }
    let!(:repl_b)    { make_replacement(creator: creator_b) }

    it "returns replacements for the specified creator" do
      results = PostReplacement.search(creator_id: creator_a.id.to_s)
      expect(results).to include(repl_a)
      expect(results).not_to include(repl_b)
    end
  end

  # --------------------------------------------------------------------------
  # approver_id (where_user)
  # --------------------------------------------------------------------------
  describe "approver_id param" do
    let!(:approver_a) { create(:user) }
    let!(:approver_b) { create(:user) }
    let!(:repl_a)     { create(:approved_post_replacement, approver: approver_a) }
    let!(:repl_b)     { create(:approved_post_replacement, approver: approver_b) }

    it "returns replacements approved by the specified approver" do
      results = PostReplacement.search(approver_id: approver_a.id.to_s)
      expect(results).to include(repl_a)
      expect(results).not_to include(repl_b)
    end
  end

  # --------------------------------------------------------------------------
  # order
  # --------------------------------------------------------------------------
  describe "order param" do
    # The ORDER expression:
    #   CASE status WHEN 'original' THEN 0 ELSE id END [ASC|DESC]
    # DESC (default): non-originals sorted newest-first, original last (value 0)
    # ASC  (id_asc):  original first (value 0), non-originals oldest-first

    let!(:original) { create(:original_post_replacement) }
    let!(:older)    { make_replacement }
    let!(:newer)    { make_replacement }

    it "defaults to DESC: places non-originals before the original" do
      ids = PostReplacement.search({}).ids
      expect(ids.index(newer.id)).to be < ids.index(original.id)
      expect(ids.index(older.id)).to be < ids.index(original.id)
    end

    it "defaults to DESC: newest non-original appears before older one" do
      ids = PostReplacement.search({}).ids
      expect(ids.index(newer.id)).to be < ids.index(older.id)
    end

    it "with id_asc: original appears first" do
      ids = PostReplacement.search(order: "id_asc").ids
      expect(ids.index(original.id)).to be < ids.index(older.id)
      expect(ids.index(original.id)).to be < ids.index(newer.id)
    end

    it "with id_asc: older non-original appears before newer" do
      ids = PostReplacement.search(order: "id_asc").ids
      expect(ids.index(older.id)).to be < ids.index(newer.id)
    end
  end
end
