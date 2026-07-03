# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostThumbnailComponent, type: :component do
  include_context "as member"

  let(:post) { create(:post) }

  def component(post, **options)
    described_class.new(post: post, **options)
  end

  describe "#preview_classes" do
    it "always includes 'thumbnail'" do
      expect(component(post).send(:preview_classes)).to include("thumbnail")
    end

    it "includes 'pending' for a pending post" do
      expect(component(create(:pending_post)).send(:preview_classes)).to include("pending")
    end

    it "does not include 'pending' for a normal post" do
      expect(component(post).send(:preview_classes)).not_to include("pending")
    end

    it "includes 'flagged' for a flagged post" do
      expect(component(create(:flagged_post)).send(:preview_classes)).to include("flagged")
    end

    it "does not include 'flagged' for a normal post" do
      expect(component(post).send(:preview_classes)).not_to include("flagged")
    end

    it "includes 'deleted' for a deleted post" do
      expect(component(create(:deleted_post)).send(:preview_classes)).to include("deleted")
    end

    it "does not include 'deleted' for a normal post" do
      expect(component(post).send(:preview_classes)).not_to include("deleted")
    end

    it "includes 'has-parent' when the post has a parent" do
      allow(post).to receive(:parent_id).and_return(1)
      expect(component(post).send(:preview_classes)).to include("has-parent")
    end

    it "does not include 'has-parent' when the post has no parent" do
      expect(component(post).send(:preview_classes)).not_to include("has-parent")
    end

    it "includes 'has-children' when the post has visible children" do
      allow(post).to receive(:has_visible_children?).and_return(true)
      expect(component(post).send(:preview_classes)).to include("has-children")
    end

    it "does not include 'has-children' when the post has no visible children" do
      expect(component(post).send(:preview_classes)).not_to include("has-children")
    end

    it "includes 'rating-safe' for a safe-rated post" do
      expect(component(create(:post, rating: "s")).send(:preview_classes)).to include("rating-safe")
    end

    it "includes 'rating-questionable' for a questionable-rated post" do
      expect(component(create(:post, rating: "q")).send(:preview_classes)).to include("rating-questionable")
    end

    it "includes 'rating-explicit' for an explicit-rated post" do
      expect(component(create(:post, rating: "e")).send(:preview_classes)).to include("rating-explicit")
    end

    it "includes 'blacklistable' by default" do
      expect(component(post).send(:preview_classes)).to include("blacklistable")
    end

    it "does not include 'blacklistable' when no_blacklist option is set" do
      expect(component(post, no_blacklist: true).send(:preview_classes)).not_to include("blacklistable")
    end
  end

  describe "ribbon" do
    it "shows no ribbons for a plain post" do
      c = component(post)
      expect(c.send(:should_show_ribbon?, :left)).to be(false)
      expect(c.send(:should_show_ribbon?, :right)).to be(false)
    end

    it "shows left ribbon if parent_id" do
      allow(post).to receive(:parent_id).and_return(1)
      expect(component(post).send(:should_show_ribbon?, :left)).to be(true)
    end

    it "shows left ribbon if has_visible_children?" do
      allow(post).to receive(:has_visible_children?).and_return(true)
      expect(component(post).send(:should_show_ribbon?, :left)).to be(true)
    end

    it "shows right ribbon if is_pending?" do
      allow(post).to receive(:is_pending?).and_return(true)
      expect(component(post).send(:should_show_ribbon?, :right)).to be(true)
    end

    it "shows right ribbon if is_flagged?" do
      allow(post).to receive(:is_flagged?).and_return(true)
      expect(component(post).send(:should_show_ribbon?, :right)).to be(true)
    end

    it "shows both ribbons" do
      allow(post).to receive_messages({ has_visible_children?: true, is_flagged?: true })
      c = component(post)
      expect(c.send(:should_show_ribbon?, :right)).to be(true)
      expect(c.send(:should_show_ribbon?, :left)).to be(true)
    end
  end
end
