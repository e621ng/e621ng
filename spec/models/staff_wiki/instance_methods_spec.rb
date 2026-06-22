# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                      StaffWiki Instance Methods                             #
# --------------------------------------------------------------------------- #

RSpec.describe StaffWiki do
  include_context "as member"

  # -------------------------------------------------------------------------
  # #revert_to
  # -------------------------------------------------------------------------
  describe "#revert_to" do
    it "loads title and body from the given version without saving" do
      wiki = create(:staff_wiki, title: generate(:staff_wiki_title), body: "original body")
      original_version = wiki.versions.first
      wiki.update!(title: generate(:staff_wiki_title), body: "updated body")

      wiki.revert_to(original_version)

      expect(wiki.title).to eq(original_version.title)
      expect(wiki.body).to eq(original_version.body)
      expect(wiki.reload.body).to eq("updated body")
    end

    it "raises StaffWiki::RevertError when the version belongs to a different page" do
      wiki1 = create(:staff_wiki)
      wiki2 = create(:staff_wiki)
      version_of_wiki2 = wiki2.versions.first

      expect { wiki1.revert_to(version_of_wiki2) }.to raise_error(StaffWiki::RevertError)
    end
  end

  # -------------------------------------------------------------------------
  # #revert_to!
  # -------------------------------------------------------------------------
  describe "#revert_to!" do
    it "persists the reverted title and body" do
      original_title = generate(:staff_wiki_title)
      wiki = create(:staff_wiki, title: original_title, body: "original body")
      original_version = wiki.versions.first
      wiki.update!(title: generate(:staff_wiki_title), body: "updated body")

      wiki.revert_to!(original_version)

      expect(wiki.reload.title).to eq(original_title)
      expect(wiki.reload.body).to eq("original body")
    end

    it "raises StaffWiki::RevertError when the version belongs to a different page" do
      wiki1 = create(:staff_wiki)
      wiki2 = create(:staff_wiki)
      version_of_wiki2 = wiki2.versions.first

      expect { wiki1.revert_to!(version_of_wiki2) }.to raise_error(StaffWiki::RevertError)
    end
  end

  # -------------------------------------------------------------------------
  # version creation (after_save :create_version)
  # -------------------------------------------------------------------------
  describe "version creation" do
    it "creates one version when a staff wiki is first created" do
      wiki = create(:staff_wiki)
      expect(wiki.versions.count).to eq(1)
    end

    it "creates a new version when the title is updated" do
      wiki = create(:staff_wiki)
      expect { wiki.update!(title: generate(:staff_wiki_title)) }.to change { wiki.versions.count }.by(1)
    end

    it "creates a new version when the body is updated" do
      wiki = create(:staff_wiki)
      expect { wiki.update!(body: "new body content") }.to change { wiki.versions.count }.by(1)
    end

    it "does not create a new version when only claimant_id is updated" do
      wiki = create(:staff_wiki)
      claimant = create(:user)
      expect { wiki.update!(claimant_id: claimant.id) }.not_to(change { wiki.versions.count })
    end
  end

  # -------------------------------------------------------------------------
  # reference creation (after_save :create_references)
  # -------------------------------------------------------------------------
  describe "reference creation" do
    it "creates a StaffWikiRef when related_type and related_id are set on create" do
      user = create(:user)
      wiki = create(:staff_wiki, related_type: "user", related_id: user.id)
      expect(wiki.references.count).to eq(1)
      expect(wiki.references.first.related).to eq(user)
    end

    it "does not create a reference when related_type and related_id are absent" do
      wiki = create(:staff_wiki)
      expect(wiki.references.count).to eq(0)
    end
  end
end
