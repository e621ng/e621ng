# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostThumbnailComponent, type: :component do
  include_context "as member"

  let(:post) { create(:post) }

  def component(post, **options)
    described_class.new(post: post, **options)
  end

  describe "#render?" do
    it "returns true for a normal post" do
      expect(component(post).render?).to be true
    end

    it "returns false when post is nil" do
      expect(component(nil).render?).to be false
    end

    it "returns false when post is loginblocked" do
      allow(post).to receive(:loginblocked?).and_return(true)
      expect(component(post).render?).to be false
    end

    it "returns false when post is safeblocked" do
      allow(post).to receive(:safeblocked?).and_return(true)
      expect(component(post).render?).to be false
    end

    context "when post is deleted" do
      let(:post) { create(:deleted_post) }

      it "returns false when TagQuery hides deleted posts" do
        allow(TagQuery).to receive(:should_hide_deleted_posts?).and_return(true)
        expect(component(post).render?).to be false
      end

      it "returns true when show_deleted option is set" do
        allow(TagQuery).to receive(:should_hide_deleted_posts?).and_return(true)
        expect(component(post, show_deleted: true).render?).to be true
      end

      it "returns true when TagQuery does not hide deleted posts" do
        allow(TagQuery).to receive(:should_hide_deleted_posts?).and_return(false)
        expect(component(post).render?).to be true
      end
    end
  end
end
