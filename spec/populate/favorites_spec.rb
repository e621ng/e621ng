# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/populate")

RSpec.describe Populate::Favorites do
  include_context "as admin"

  it "creates unique favorites and keeps the counts in step" do
    users = create_list(:user, 2, created_at: 1.month.ago)
    posts = create_list(:post, 3)

    expect { described_class.new(count: 20, users: users).call }.to output.to_stdout

    expect(Favorite.count).to be_between(1, 6)
    expect(Favorite.group(:user_id, :post_id).count.values).to all(eq(1))
    posts.each { |post| expect(post.reload.fav_count).to eq(Favorite.where(post_id: post.id).count) }
    users.each { |user| expect(user.user_status.reload.favorite_count).to eq(Favorite.where(user_id: user.id).count) }
  end
end
