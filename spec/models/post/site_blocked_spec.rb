# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as member"

  describe "#siteblocked?" do
    let(:pony_post) { create(:post, tag_string: "my_little_pony twilight_sparkle") }
    let(:other_post) { create(:post, tag_string: "dragon solo") }

    it "is false on the primary site" do
      expect(other_post).not_to be_siteblocked
      expect(other_post).to be_visible
    end

    context "on a tag-locked site" do
      include_context "with tag-locked site profile"

      # RequestStore is cleared after each example by rails_helper
      before { CurrentSite.apply!(CurrentSite.find("mlp"), false) }

      it "blocks posts missing a required tag" do
        expect(other_post).to be_siteblocked
        expect(other_post).not_to be_visible
        expect(other_post).not_to be_safeblocked
      end

      it "allows posts carrying every required tag" do
        expect(pony_post).not_to be_siteblocked
        expect(pony_post).to be_visible
      end

      it "requires all tags" do
        allow(CurrentSite).to receive(:required_tags).and_return(%w[my_little_pony friendship_is_magic])
        expect(pony_post).to be_siteblocked
      end

      it "hides the thumbnail" do
        expect(PostThumbnailComponent.new(post: other_post).render?).to be(false)
        expect(PostThumbnailComponent.new(post: pony_post).render?).to be(true)
      end

      it "is listed separately from safe-mode hidden posts" do
        set = PostSets::Post.new("")
        allow(set).to receive(:posts).and_return([pony_post, other_post])
        expect(set.site_blocked_posts).to eq([other_post])
        expect(set.safe_posts).to be_empty
        expect(set.hidden_posts).to eq([other_post])
      end
    end
  end
end
