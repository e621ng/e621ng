# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/populate")

RSpec.describe Populate::Comments do
  include_context "as admin"

  it "creates comments by the given users on existing posts" do
    users = create_list(:user, 2, created_at: 1.month.ago)
    create_list(:post, 2)

    comments = nil
    expect { comments = described_class.new(count: 3, users: users).call }.to output.to_stdout

    expect(comments.size).to eq(3)
    expect(comments.map(&:creator_id)).to all(be_in(users.map(&:id)))
    expect(Comment.count).to eq(3)
  end
end
