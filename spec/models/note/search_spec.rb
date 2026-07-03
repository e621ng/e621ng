# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           Note Search                                       #
# --------------------------------------------------------------------------- #

RSpec.describe Note do
  include_context "as admin"

  def make_note(overrides = {})
    create(:note, **overrides)
  end

  # -------------------------------------------------------------------------
  # Shared fixtures
  # -------------------------------------------------------------------------
  let!(:note_alpha)    { make_note(body: "unique alpha content") }
  let!(:note_beta)     { make_note(body: "unique beta content") }
  let!(:note_inactive) { create(:inactive_note) }

  # -------------------------------------------------------------------------
  # body_matches param
  # -------------------------------------------------------------------------
  describe "body_matches param (full-text)" do
    it "returns notes whose body matches the search term" do
      result = Note.search(body_matches: "alpha")
      expect(result).to include(note_alpha)
      expect(result).not_to include(note_beta)
    end

    it "returns all notes when body_matches is absent" do
      result = Note.search({})
      expect(result).to include(note_alpha, note_beta)
    end
  end

  describe "body_matches param (wildcard)" do
    it "supports a trailing wildcard" do
      result = Note.search(body_matches: "unique alpha*")
      expect(result).to include(note_alpha)
      expect(result).not_to include(note_beta)
    end
  end

  # -------------------------------------------------------------------------
  # is_active param
  # -------------------------------------------------------------------------
  describe "is_active param" do
    it "returns only active notes when is_active is 'true'" do
      result = Note.search(is_active: "true")
      expect(result).to include(note_alpha)
      expect(result).not_to include(note_inactive)
    end

    it "returns only inactive notes when is_active is 'false'" do
      result = Note.search(is_active: "false")
      expect(result).to include(note_inactive)
      expect(result).not_to include(note_alpha)
    end
  end

  # -------------------------------------------------------------------------
  # post_id param
  # -------------------------------------------------------------------------
  describe "post_id param" do
    it "filters notes by a single post id" do
      result = Note.search(post_id: note_alpha.post_id.to_s)
      expect(result).to include(note_alpha)
      expect(result).not_to include(note_beta)
    end

    it "filters notes by multiple comma-separated post ids" do
      result = Note.search(post_id: "#{note_alpha.post_id},#{note_beta.post_id}")
      expect(result).to include(note_alpha, note_beta)
    end
  end

  # -------------------------------------------------------------------------
  # post_tags_match param
  # -------------------------------------------------------------------------
  describe "post_tags_match param" do
    it "returns notes on posts matching the given tag" do
      tag = note_alpha.post.tag_array.first
      result = Note.search(post_tags_match: tag)
      expect(result).to include(note_alpha)
    end
  end

  # -------------------------------------------------------------------------
  # creator_name / creator_id params
  # -------------------------------------------------------------------------
  describe "creator_name param" do
    it "returns only notes from the named creator" do
      other_user  = create(:user)
      other_note  = CurrentUser.scoped(other_user, "127.0.0.1") { make_note(body: "other creator note") }

      result = Note.search(creator_name: CurrentUser.name)
      expect(result).to include(note_alpha, note_beta)
      expect(result).not_to include(other_note)
    end
  end

  describe "creator_id param" do
    it "returns only notes from the given creator id" do
      result = Note.search(creator_id: note_alpha.creator_id.to_s)
      expect(result).to include(note_alpha)
    end
  end

  # -------------------------------------------------------------------------
  # post_note_updater_name / post_note_updater_id params
  # -------------------------------------------------------------------------
  describe "post_note_updater_name param" do
    it "returns notes on posts that were updated by the named user" do
      other_updater = create(:user)
      # Create a note then update it as other_updater, which creates a NoteVersion
      # with updater_id = other_updater.id on that post
      note_updated_by_other = make_note(body: "will be updated")
      CurrentUser.scoped(other_updater, "127.0.0.1") do
        note_updated_by_other.update!(body: "updated by other")
      end

      result = Note.search(post_note_updater_name: other_updater.name)
      expect(result).to include(note_updated_by_other)
      expect(result).not_to include(note_alpha)
    end
  end

  describe "post_note_updater_id param" do
    it "returns notes on posts that were updated by the given user id" do
      other_updater = create(:user)
      note_updated_by_other = make_note(body: "will be updated by id")
      CurrentUser.scoped(other_updater, "127.0.0.1") do
        note_updated_by_other.update!(body: "updated by other id")
      end

      result = Note.search(post_note_updater_id: other_updater.id.to_s)
      expect(result).to include(note_updated_by_other)
      expect(result).not_to include(note_alpha)
    end
  end
end
