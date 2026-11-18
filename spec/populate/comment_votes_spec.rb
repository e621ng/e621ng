# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/populate")

RSpec.describe Populate::CommentVotes do
  include_context "as admin"

  it "votes on comments by other users" do
    author = create(:user, created_at: 1.month.ago)
    voters = create_list(:user, 2, created_at: 1.month.ago)
    comments = create_list(:comment, 2, creator: author, creator_ip_addr: "127.0.0.1")

    expect { described_class.new(count: 4, users: voters, comments: comments).call }.to output.to_stdout

    expect(CommentVote.count).to be_between(1, 4)
    expect(CommentVote.pluck(:comment_id)).to all(be_in(comments.map(&:id)))
  end
end
