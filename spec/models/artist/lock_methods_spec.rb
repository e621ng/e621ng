# frozen_string_literal: true

# This model does not exist in this fork.
return if true # rubocop:disable Lint/LiteralAsCondition

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         Artist::LockMethods                                 #
# --------------------------------------------------------------------------- #

RSpec.describe Artist do
  include_context "as admin"

  def make_artist(overrides = {})
    create(:artist, **overrides)
  end

  # -------------------------------------------------------------------------
  # #propagate_locked (after_save when is_locked changes)
  # -------------------------------------------------------------------------
  describe "#propagate_locked" do
    it "locks the associated wiki page when the artist is locked" do
      artist = make_artist
      create(:wiki_page, title: artist.name, is_locked: false)
      artist.reload

      artist.update!(is_locked: true)
      expect(artist.wiki_page.reload.is_locked).to be true
    end

    it "unlocks the associated wiki page when the artist is unlocked" do
      artist = create(:locked_artist)
      create(:wiki_page, title: artist.name, is_locked: true)
      artist.reload

      artist.update!(is_locked: false)
      expect(artist.wiki_page.reload.is_locked).to be false
    end

    it "does not raise when the artist has no wiki page" do
      artist = make_artist
      expect { artist.update!(is_locked: true) }.not_to raise_error
    end
  end

  # -------------------------------------------------------------------------
  # #validate_user_can_edit
  # -------------------------------------------------------------------------
  describe "#validate_user_can_edit" do
    it "allows a janitor to edit a locked artist" do
      artist = create(:locked_artist)
      CurrentUser.user = create(:janitor_user)
      artist.group_name = "any_group"
      expect(artist).to be_valid
    end

    it "blocks a member from editing a locked artist" do
      artist = create(:locked_artist)
      CurrentUser.user = create(:user)
      artist.group_name = "any_group"
      expect(artist).not_to be_valid
      expect(artist.errors[:base]).to include("Artist is locked")
    end

    it "allows a member to edit an unlocked artist" do
      artist = make_artist
      CurrentUser.user = create(:user)
      artist.group_name = "any_group"
      expect(artist).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # #wiki_page_not_locked
  # -------------------------------------------------------------------------
  describe "#wiki_page_not_locked" do
    it "allows a janitor to set notes when the wiki page is locked" do
      artist = make_artist
      create(:locked_wiki_page, title: artist.name)
      artist.reload
      CurrentUser.user = create(:janitor_user)
      artist.notes = "janitor notes"
      expect(artist).to be_valid
    end

    it "blocks a member from setting notes when the wiki page is locked" do
      artist = make_artist
      create(:locked_wiki_page, title: artist.name, body: "existing body")
      artist.reload
      CurrentUser.user = create(:user)
      artist.notes = "member notes"
      expect(artist).not_to be_valid
      expect(artist.errors[:base]).to include("Wiki page is locked")
    end

    it "allows a member to set notes when the wiki page is not locked" do
      artist = make_artist
      create(:wiki_page, title: artist.name, is_locked: false)
      artist.reload
      CurrentUser.user = create(:user)
      artist.notes = "unlocked notes"
      expect(artist).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # #editable_by?
  # -------------------------------------------------------------------------
  describe "#editable_by?" do
    it "returns true for a janitor regardless of lock state" do
      janitor = create(:janitor_user)
      expect(create(:locked_artist).editable_by?(janitor)).to be true
      expect(make_artist.editable_by?(janitor)).to be true
    end

    it "returns true for a member when the artist is unlocked" do
      expect(make_artist.editable_by?(create(:user))).to be true
    end

    it "returns false for a member when the artist is locked" do
      expect(create(:locked_artist).editable_by?(create(:user))).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #is_note_locked?
  # -------------------------------------------------------------------------
  describe "#is_note_locked?" do
    it "returns false when no wiki page exists" do
      expect(make_artist.is_note_locked?).to be false
    end

    it "returns false for a janitor even when the wiki page is locked" do
      artist = make_artist
      create(:locked_wiki_page, title: artist.name)
      artist.reload
      CurrentUser.user = create(:janitor_user)
      expect(artist.is_note_locked?).to be false
    end

    it "returns true for a member when the wiki page is locked" do
      artist = make_artist
      create(:locked_wiki_page, title: artist.name)
      artist.reload
      CurrentUser.user = create(:user)
      expect(artist.is_note_locked?).to be true
    end

    it "returns false for a member when the wiki page is not locked" do
      artist = make_artist
      create(:wiki_page, title: artist.name, is_locked: false)
      artist.reload
      CurrentUser.user = create(:user)
      expect(artist.is_note_locked?).to be false
    end
  end
end
