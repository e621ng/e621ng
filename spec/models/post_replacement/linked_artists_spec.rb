# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostReplacement do
  describe "Uploader linked artists:", skip: "This test is skipped on this fork" do
    let(:user) { create(:user, created_at: 2.weeks.ago) }
    let(:mod_user) { create(:moderator_user, created_at: 2.weeks.ago) }

    it "only returns artist tags linked to the replacement creator" do
      CurrentUser.scoped(mod_user) do
        create(:artist, name: "test_match_(artist)", linked_user: user)
        create(:artist, name: "test_other_(artist)", linked_user: create(:user))
        create(:artist, name: "test_unlinked_(artist)")
      end

      post = create(:post, tag_string: "test_match_(artist) test_other_(artist) test_unlinked_(artist)", uploader: mod_user)
      replacement = build(:post_replacement, post: post, creator: user)

      expect(replacement.uploader_linked_artists).to eq(["test_match_(artist)"])
    end

    it "ignores artist tags without an artist entry" do
      CurrentUser.scoped(mod_user) { create(:artist_tag, name: "missing_(artist)") }

      post = create(:post, tag_string: "missing_(artist)", uploader: mod_user)
      replacement = build(:post_replacement, post: post, creator: user)

      expect(replacement.uploader_linked_artists).to eq([])
    end
  end
end
