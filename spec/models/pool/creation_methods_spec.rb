# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoolsController, ".create" do
  let(:user) { create(:user, created_at: 2.weeks.ago) }
  let(:posts) { CurrentUser.scoped(user) { create_list(:post, 5) } }
  let(:pool) { CurrentUser.scoped(user) { create(:pool, post_ids: posts.map(&:id)) } }

  it "initializes the post count" do
    expect(pool.post_count).to eq(posts.size)
  end

  it "synchronize the posts with the pool" do
    expect(pool.post_ids).to eq(posts.map(&:id))

    posts.each(&:reload)
    expect(posts.map(&:pool_string)).to eq(["pool:#{pool.id}"] * posts.size)
  end

  it "error when post ids are invalid" do
    CurrentUser.scoped(user) do
      expect { create(:pool, post_ids: posts.map { |p| p.id << 3 }) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  it "error when post ids are out of range" do
    invalid_id = ParseValue::MAX_INT + 1
    CurrentUser.scoped(user) do
      expect { create(:pool, post_ids: [invalid_id]) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
