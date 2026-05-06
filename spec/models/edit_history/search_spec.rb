# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        EditHistory Search & Scopes                          #
# --------------------------------------------------------------------------- #

RSpec.describe EditHistory do
  include_context "as admin"

  let(:editor_a) { create(:user) }
  let(:editor_b) { create(:user) }
  let(:blip_a)   { create(:blip) }
  let(:blip_b)   { create(:blip) }
  let(:forum_post) { create(:forum_post) }

  let!(:edit_alpha) do
    create(:edit_history,
           body: "alpha body content",
           subject: nil,
           user: editor_a,
           versionable: blip_a,
           ip_addr: "10.0.0.1",
           version: 1)
  end

  let!(:edit_beta) do
    create(:edit_history,
           body: "beta body content",
           subject: "beta subject",
           user: editor_b,
           versionable: blip_b,
           ip_addr: "192.168.1.1",
           version: 1)
  end

  let!(:edit_forum) do
    create(:edit_history,
           body: "forum body content",
           subject: "forum subject line",
           user: editor_a,
           versionable: forum_post,
           ip_addr: "10.0.0.2",
           version: 1)
  end

  # -------------------------------------------------------------------------
  # body_matches param
  # -------------------------------------------------------------------------
  describe "body_matches param" do
    it "returns records whose body matches the term" do
      result = EditHistory.search(body_matches: "alpha")
      expect(result).to include(edit_alpha)
      expect(result).not_to include(edit_beta)
    end

    it "returns all records when body_matches is absent" do
      result = EditHistory.search({})
      expect(result).to include(edit_alpha, edit_beta, edit_forum)
    end
  end

  # -------------------------------------------------------------------------
  # subject_matches param
  # -------------------------------------------------------------------------
  describe "subject_matches param" do
    it "returns records whose subject matches the term" do
      result = EditHistory.search(subject_matches: "forum subject")
      expect(result).to include(edit_forum)
      expect(result).not_to include(edit_alpha)
    end

    it "returns all records when subject_matches is absent" do
      result = EditHistory.search({})
      expect(result).to include(edit_alpha, edit_beta, edit_forum)
    end
  end

  # -------------------------------------------------------------------------
  # versionable_type param
  # -------------------------------------------------------------------------
  describe "versionable_type param" do
    it "filters to Blip edit histories" do
      result = EditHistory.search(versionable_type: "Blip")
      expect(result).to include(edit_alpha, edit_beta)
      expect(result).not_to include(edit_forum)
    end

    it "filters to ForumPost edit histories" do
      result = EditHistory.search(versionable_type: "ForumPost")
      expect(result).to include(edit_forum)
      expect(result).not_to include(edit_alpha, edit_beta)
    end

    it "returns all records when versionable_type is absent" do
      result = EditHistory.search({})
      expect(result).to include(edit_alpha, edit_beta, edit_forum)
    end
  end

  # -------------------------------------------------------------------------
  # versionable_id param
  # -------------------------------------------------------------------------
  describe "versionable_id param" do
    it "filters by the given versionable id" do
      result = EditHistory.search(versionable_id: blip_a.id.to_s)
      expect(result).to include(edit_alpha)
      expect(result).not_to include(edit_beta, edit_forum)
    end

    it "returns all records when versionable_id is absent" do
      result = EditHistory.search({})
      expect(result).to include(edit_alpha, edit_beta, edit_forum)
    end
  end

  # -------------------------------------------------------------------------
  # editor_name param
  # -------------------------------------------------------------------------
  describe "editor_name param" do
    it "returns only edits made by the named user" do
      result = EditHistory.search(editor_name: editor_a.name)
      expect(result).to include(edit_alpha, edit_forum)
      expect(result).not_to include(edit_beta)
    end

    it "returns all records when editor_name is absent" do
      result = EditHistory.search({})
      expect(result).to include(edit_alpha, edit_beta, edit_forum)
    end
  end

  # -------------------------------------------------------------------------
  # editor_id param
  # -------------------------------------------------------------------------
  describe "editor_id param" do
    it "returns only edits made by the given user id" do
      result = EditHistory.search(editor_id: editor_b.id.to_s)
      expect(result).to include(edit_beta)
      expect(result).not_to include(edit_alpha, edit_forum)
    end
  end

  # -------------------------------------------------------------------------
  # ip_addr param
  # -------------------------------------------------------------------------
  describe "ip_addr param" do
    it "returns records whose ip_addr falls within the given CIDR range" do
      result = EditHistory.search(ip_addr: "10.0.0.0/24")
      expect(result).to include(edit_alpha, edit_forum)
      expect(result).not_to include(edit_beta)
    end

    it "returns no records when ip_addr is outside all stored addresses" do
      result = EditHistory.search(ip_addr: "172.16.0.0/12")
      expect(result).not_to include(edit_alpha, edit_beta, edit_forum)
    end
  end

  # -------------------------------------------------------------------------
  # order param
  # -------------------------------------------------------------------------
  describe "order param" do
    it "orders by id ascending when order is 'id_asc'" do
      ids = EditHistory.search(order: "id_asc").ids
      expect(ids).to eq(ids.sort)
    end

    it "orders by id descending when order is 'id_desc'" do
      ids = EditHistory.search(order: "id_desc").ids
      expect(ids).to eq(ids.sort.reverse)
    end

    it "defaults to newest-first (id desc) when order is absent" do
      ids = EditHistory.search({}).ids
      expect(ids).to eq(ids.sort.reverse)
    end
  end
end
