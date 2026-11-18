# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/populate")

RSpec.describe Populate::PostVotes do
  include_context "as admin"

  it "votes on the given posts" do
    users = create_list(:user, 2, created_at: 1.month.ago)
    posts = create_list(:post, 2)

    expect { described_class.new(count: 4, users: users, posts: posts).call }.to output.to_stdout

    expect(PostVote.count).to be_between(1, 4)
    expect(PostVote.pluck(:post_id)).to all(be_in(posts.map(&:id)))
  end
end
