# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostThumbnailComponent, type: :component do
  include_context "as member"

  let(:post) { create(:post) }
  let(:pool) { create(:pool) }

  def component(post, **options)
    described_class.new(post: post, **options)
  end

  describe "#should_show_similarity?" do
    it "returns false when no similarity option is given" do
      expect(component(post).send(:should_show_similarity?)).to be false
    end

    it "returns true when a similarity value is given" do
      expect(component(post, similarity: 95).send(:should_show_similarity?)).to be true
    end
  end

  describe "#should_show_pool?" do
    it "returns false when no pool option is given" do
      expect(component(post).send(:should_show_pool?)).to be false
    end

    it "returns true when a pool is given" do
      expect(component(post, pool: pool).send(:should_show_pool?)).to be true
    end
  end

  describe "#pool_name" do
    it "returns the pool's pretty name when it is short" do
      allow(pool).to receive(:pretty_name).and_return("Short Name")
      expect(component(post, pool: pool).send(:pool_name)).to eq("Short Name")
    end

    it "truncates the pool name to 80 characters" do
      long_name = "a" * 100
      allow(pool).to receive(:pretty_name).and_return(long_name)
      result = component(post, pool: pool).send(:pool_name)
      expect(result.length).to be <= 80
    end
  end

  describe "#should_render_image?" do
    it "returns true for a non-deleted post" do
      expect(component(post).send(:should_render_image?)).to be true
    end

    it "returns false for a deleted post viewed by a regular member" do
      deleted = create(:deleted_post)
      expect(component(deleted).send(:should_render_image?)).to be false
    end

    context "when post is deleted" do
      let(:deleted) { create(:deleted_post) }

      it "returns true for a janitor" do
        janitor = create(:janitor_user)
        CurrentUser.user = janitor
        expect(component(deleted).send(:should_render_image?)).to be true
      end

      it "returns true for a user who can approve posts" do
        approver = create(:user)
        allow(approver).to receive(:can_approve_posts?).and_return(true)
        CurrentUser.user = approver
        expect(component(deleted).send(:should_render_image?)).to be true
      end
    end
  end
end
