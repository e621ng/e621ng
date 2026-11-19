# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostSets::Popular do
  include_context "as member"

  let!(:pony_post) { create(:post, tag_string: "my_little_pony twilight_sparkle") }
  let!(:other_post) { create(:post, tag_string: "dragon solo") }

  it "lists every post on the primary site" do
    expect(described_class.new(nil, "day").posts).to contain_exactly(pony_post, other_post)
  end

  context "on a tag-locked site" do
    include_context "with tag-locked site profile"

    it "lists only posts carrying the required tags" do
      posts = CurrentSite.with("mlp") { described_class.new(nil, "day").posts.to_a }
      expect(posts).to eq([pony_post])
    end
  end
end
