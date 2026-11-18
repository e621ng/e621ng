# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/populate")

RSpec.describe Populate::Forums do
  include_context "as admin"

  let(:users) { create_list(:user, 2, created_at: 1.month.ago) }

  it "counts the opening post, so COUNT=1 is a topic without replies" do
    expect { described_class.new(count: 1, users: users).call }.to output.to_stdout

    expect(ForumTopic.count).to eq(1)
    expect(ForumPost.count).to eq(1)
  end

  it "creates the replies" do
    expect { described_class.new(count: 3, users: users).call }.to output.to_stdout

    expect(ForumTopic.count).to eq(1)
    expect(ForumPost.count).to eq(3)
  end
end
