# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         Artist Log Methods                                  #
# --------------------------------------------------------------------------- #

RSpec.describe Artist do
  include_context "as admin"

  def make_artist(overrides = {})
    create(:artist, **overrides)
  end

  # -------------------------------------------------------------------------
  # artist_page_rename
  # -------------------------------------------------------------------------
  describe "log_changes — rename" do
    it "logs artist_page_rename when name changes on update" do
      artist = make_artist
      expect do
        artist.update!(name: "#{artist.name}_renamed")
      end.to change(ModAction.where(action: "artist_page_rename"), :count).by(1)
    end

    it "records old_name and new_name in ModAction values" do
      artist = make_artist
      old_name = artist.name
      new_name = "#{old_name}_renamed"
      artist.update!(name: new_name)
      log = ModAction.where(action: "artist_page_rename").last
      expect(log[:values]).to include("old_name" => old_name, "new_name" => new_name)
    end

    it "does NOT log a rename on create" do
      initial_count = ModAction.where(action: "artist_page_rename").count
      make_artist
      expect(ModAction.where(action: "artist_page_rename").count).to eq(initial_count)
    end
  end

  # -------------------------------------------------------------------------
  # artist_page_lock / artist_page_unlock
  # -------------------------------------------------------------------------
  describe "log_changes — lock/unlock" do
    it "logs artist_page_lock when is_locked changes to true" do
      artist = make_artist
      expect do
        artist.update!(is_locked: true)
      end.to change(ModAction.where(action: "artist_page_lock"), :count).by(1)
    end

    it "records the artist id in the lock ModAction" do
      artist = make_artist
      artist.update!(is_locked: true)
      log = ModAction.where(action: "artist_page_lock").last
      expect(log[:values]).to include("artist_page" => artist.id)
    end

    it "logs artist_page_unlock when is_locked changes to false" do
      artist = create(:locked_artist)
      expect do
        artist.update!(is_locked: false)
      end.to change(ModAction.where(action: "artist_page_unlock"), :count).by(1)
    end

    it "does NOT log a lock action on create" do
      initial_count = ModAction.where(action: "artist_page_lock").count
      make_artist
      expect(ModAction.where(action: "artist_page_lock").count).to eq(initial_count)
    end
  end

  # -------------------------------------------------------------------------
  # artist_user_linked / artist_user_unlinked
  # -------------------------------------------------------------------------
  describe "log_changes — linked_user" do
    it "logs artist_user_linked when a user is linked" do
      artist = make_artist
      linked = create(:user)
      expect do
        artist.update!(linked_user_id: linked.id)
      end.to change(ModAction.where(action: "artist_user_linked"), :count).by(1)
    end

    it "records artist_page and user_id when linking" do
      artist = make_artist
      linked = create(:user)
      artist.update!(linked_user_id: linked.id)
      log = ModAction.where(action: "artist_user_linked").last
      expect(log[:values]).to include("artist_page" => artist.id, "user_id" => linked.id)
    end

    it "logs artist_user_unlinked when a linked user is removed" do
      linked = create(:user)
      artist = make_artist
      artist.update!(linked_user_id: linked.id)
      expect do
        artist.update!(linked_user_id: nil)
      end.to change(ModAction.where(action: "artist_user_unlinked"), :count).by(1)
    end

    it "records artist_page and previous user_id when unlinking" do
      linked = create(:user)
      artist = make_artist
      artist.update!(linked_user_id: linked.id)
      artist.update!(linked_user_id: nil)
      log = ModAction.where(action: "artist_user_unlinked").last
      expect(log[:values]).to include("artist_page" => artist.id, "user_id" => linked.id)
    end
  end

  # -------------------------------------------------------------------------
  # artist_delete (before_destroy)
  # -------------------------------------------------------------------------
  describe "#log_destroy" do
    it "logs artist_delete when the artist is destroyed" do
      artist = make_artist
      artist_id   = artist.id
      artist_name = artist.name
      artist.destroy!
      log = ModAction.where(action: "artist_delete").last
      expect(log).to be_present
      expect(log[:values]).to include("artist_id" => artist_id, "artist_name" => artist_name)
    end
  end
end
