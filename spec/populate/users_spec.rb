# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/populate")

RSpec.describe Populate::Users do
  include_context "as admin"

  it "creates the requested number of users with statuses" do
    users = nil
    expect { users = described_class.new(count: 3, password: "hexerade").call }.to output.to_stdout

    expect(users.size).to eq(3)
    expect(users).to all(be_a(User))
    expect(UserStatus.where(user_id: users.map(&:id)).count).to eq(3)
    expect(User.authenticate(users.first.name, "hexerade")).to eq(users.first)
  end

  it "does nothing for a zero count" do
    expect { expect(described_class.new(count: 0).call).to eq([]) }.not_to change(User, :count)
  end
end
