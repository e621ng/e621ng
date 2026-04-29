# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostThumbnailComponent, type: :component do
  include_context "as member"

  let(:post) { create(:post) }

  def component(post, **options)
    described_class.new(post: post, **options)
  end

  describe "#link_params" do
    it "returns an empty hash when no relevant options are given" do
      expect(component(post).send(:link_params)).to eq({})
    end

    it "includes 'q' when tags option is present" do
      expect(component(post, tags: "fluffy").send(:link_params)).to include("q" => "fluffy")
    end

    it "includes 'pool_id' when pool_id option is present" do
      expect(component(post, pool_id: 42).send(:link_params)).to include("pool_id" => 42)
    end

    it "includes 'post_set_id' when post_set_id option is present" do
      expect(component(post, post_set_id: 7).send(:link_params)).to include("post_set_id" => 7)
    end

    it "omits 'q' when tags option is blank" do
      expect(component(post, tags: "").send(:link_params)).not_to have_key("q")
    end
  end

  describe "#link_target" do
    it "returns the post when no link_target option is given" do
      expect(component(post).send(:link_target)).to eq(post)
    end

    it "returns the override when link_target option is given" do
      other = create(:post)
      expect(component(post, link_target: other).send(:link_target)).to eq(other)
    end
  end

  describe "#alt_text" do
    it "returns 'post #<id>'" do
      expect(component(post).send(:alt_text)).to eq("post ##{post.id}")
    end
  end

  describe "#image_attributes" do
    it "returns an empty hash when post_counter is -1 (default)" do
      expect(component(post).send(:image_attributes)).to eq({})
    end

    it "sets fetchpriority: 'high' for post_counter 0" do
      expect(described_class.new(post: post, post_counter: 0).send(:image_attributes)).to include(fetchpriority: "high")
    end

    it "sets fetchpriority: 'high' for post_counter 4" do
      expect(described_class.new(post: post, post_counter: 4).send(:image_attributes)).to include(fetchpriority: "high")
    end

    it "sets loading: 'lazy' for post_counter 5" do
      expect(described_class.new(post: post, post_counter: 5).send(:image_attributes)).to include(loading: "lazy")
    end

    it "sets loading: 'lazy' for post_counter 100" do
      expect(described_class.new(post: post, post_counter: 100).send(:image_attributes)).to include(loading: "lazy")
    end

    it "does not set fetchpriority for post_counter 5" do
      expect(described_class.new(post: post, post_counter: 5).send(:image_attributes)).not_to have_key(:fetchpriority)
    end
  end
end
