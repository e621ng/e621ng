# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostThumbnailComponent, type: :component do
  include_context "as member"

  describe ".with_collection" do
    it "preloads favorite and vote status so rendering does not query per post" do
      user = CurrentUser.user
      favorited = create(:post)
      voted = create(:post)
      Favorite.create!(user_id: user.id, post_id: favorited.id)
      PostVote.create!(post: voted, user: user, score: 1)

      described_class.with_collection([favorited, voted])

      allow(Favorite).to receive(:exists?)
      allow(PostVote).to receive(:where)
      expect(favorited.favorited_by?(user.id)).to be true
      expect(voted.vote_by(user.id)).to eq(1)
      expect(Favorite).not_to have_received(:exists?)
      expect(PostVote).not_to have_received(:where)
    end
  end
end
