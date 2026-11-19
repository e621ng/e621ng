# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostSets::Favorites do
  include_context "as member"

  let(:user) { CurrentUser.user }
  let!(:pony_post) { create(:post, tag_string: "my_little_pony twilight_sparkle") }
  let!(:other_post) { create(:post, tag_string: "dragon solo", rating: "e") }

  before do
    CurrentUser.safe_mode = false # not reset between examples
    FavoriteManager.add!(user: user, post: other_post)
    FavoriteManager.add!(user: user, post: pony_post)
    # The count comes from OpenSearch; the listing is SQL
    allow(Post).to receive(:tag_match).and_return(double(count_only: 2))
  end

  it "counts favorites without site or safe-mode filters" do
    described_class.new(user, 1, limit: 1).posts
    expect(Post).to have_received(:tag_match).with("fav:#{user.name} status:any", enable_safe_mode: false, required_tags: [])
  end

  context "on a tag-locked site" do
    include_context "with tag-locked site profile"

    before { CurrentSite.apply!(CurrentSite.find("mlp"), false) }

    it "keeps every favorite reachable, hiding the ones outside the scope" do
      page1 = described_class.new(user, 1, limit: 1)
      page2 = described_class.new(user, 2, limit: 1)
      expect(page1.posts).to eq([pony_post])
      expect(page2.posts).to eq([other_post])
      expect(page2.posts.total_count).to eq(2)
      expect(page2.site_blocked_posts).to eq([other_post])
    end
  end

  it "keeps every favorite reachable in safe mode" do
    CurrentUser.safe_mode = true
    page2 = described_class.new(user, 2, limit: 1)
    expect(page2.posts).to eq([other_post])
    expect(page2.safe_posts).to eq([other_post])
  end
end
