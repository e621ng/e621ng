# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostReplacementNote do
  include_context "as admin"

  describe "#visible_to?" do
    it "returns true for the creator" do
      replacement = create(:post_replacement)
      note = PostReplacementNote.create!(post_replacement: replacement, note: "test note")

      expect(note.visible_to?(replacement.creator)).to be true
    end

    it "returns true for staff" do
      replacement = create(:post_replacement)
      note = PostReplacementNote.create!(post_replacement: replacement, note: "test note")

      expect(note.visible_to?(create(:moderator_user))).to be true
    end

    it "returns false for a non-staff user who did not create the replacement" do
      replacement = create(:post_replacement)
      note = PostReplacementNote.create!(post_replacement: replacement, note: "test note")

      expect(note.visible_to?(create(:user))).to be false
    end
  end
end
