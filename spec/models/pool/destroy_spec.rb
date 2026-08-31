# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pool, "#destroy" do
  include_context "as admin"

  it "enqueues the cleanup job" do
    pool = create(:pool)

    expect { pool.destroy }
      .to enqueue_sidekiq_job(PostSetCleanupJob).with("pool", pool.id)
  end

  it "clears the members' pool_ids once the cleanup job runs" do
    User.system.update_columns(created_at: 8.days.ago)
    post = create(:post)
    pool = create(:pool, post_ids: [post.id])
    expect(post.reload[:pool_ids]).to eq([pool.id])

    pool.destroy
    PostSetCleanupJob.new.perform("pool", pool.id)

    expect(post.reload[:pool_ids]).to eq([])
  end
end
