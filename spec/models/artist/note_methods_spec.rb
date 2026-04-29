# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         Artist::NoteMethods                                 #
# --------------------------------------------------------------------------- #

RSpec.describe Artist do
  include_context "as admin"

  def make_artist(overrides = {})
    create(:artist, **overrides)
  end

  # -------------------------------------------------------------------------
  # #notes getter
  # -------------------------------------------------------------------------
  describe "#notes" do
    it "returns nil when no wiki page exists" do
      artist = make_artist
      expect(artist.notes).to be_nil
    end

    it "delegates to the wiki_page body when one exists" do
      artist = make_artist
      create(:wiki_page, title: artist.name, body: "some notes")
      artist.reload
      expect(artist.notes).to eq("some notes")
    end
  end

  # -------------------------------------------------------------------------
  # #notes= and #update_wiki — wiki page creation
  # -------------------------------------------------------------------------
  describe "#notes= and wiki page creation" do
    it "creates a wiki page when notes are set and none exists" do
      artist = make_artist
      expect do
        artist.update!(notes: "new note body")
      end.to change(WikiPage, :count).by(1)
      expect(WikiPage.titled(artist.name).body).to eq("new note body")
    end

    it "does not create a wiki page when notes are blank" do
      artist = make_artist
      expect do
        artist.notes = ""
        artist.save!
      end.not_to change(WikiPage, :count)
    end
  end

  # -------------------------------------------------------------------------
  # #update_wiki — updating an existing wiki page body
  # -------------------------------------------------------------------------
  describe "#update_wiki — body update" do
    it "updates the wiki page body when notes change" do
      artist = make_artist
      artist.update!(notes: "initial notes")
      artist.reload
      artist.update!(notes: "updated notes")
      expect(WikiPage.titled(artist.name).body).to eq("updated notes")
    end

    it "does not update the wiki page when notes are unchanged" do
      artist = make_artist
      artist.update!(notes: "stable notes")
      wiki = WikiPage.titled(artist.name)
      expect { artist.update!(group_name: "some_group") }.not_to(change { wiki.reload.body })
    end
  end

  # -------------------------------------------------------------------------
  # #update_wiki — wiki page rename when artist is renamed
  # -------------------------------------------------------------------------
  describe "#update_wiki — rename" do
    it "renames the wiki page when the artist is renamed" do
      artist = make_artist
      artist.update!(notes: "rename me")
      old_name = artist.name
      new_name = "#{old_name}_renamed"

      artist.update!(name: new_name)

      expect(WikiPage.titled(new_name)).to be_present
      expect(WikiPage.titled(old_name)).to be_nil
    end
  end

  # -------------------------------------------------------------------------
  # #notes_changed?
  # -------------------------------------------------------------------------
  describe "#notes_changed?" do
    it "returns false before any notes assignment" do
      artist = make_artist
      expect(artist.notes_changed?).to be false
    end

    it "returns true after notes= is called with a new value" do
      artist = make_artist
      artist.update!(notes: "initial")
      artist.reload
      artist.notes = "changed"
      expect(artist.notes_changed?).to be true
    end

    it "returns false after reload clears the in-memory notes state" do
      artist = make_artist
      artist.update!(notes: "some notes")
      artist.reload
      expect(artist.notes_changed?).to be false
    end
  end
end
