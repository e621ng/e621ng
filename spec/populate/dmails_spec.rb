# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/populate")

RSpec.describe Populate::Dmails do
  include_context "as admin"

  it "sends dmails between existing users" do
    create_list(:user, 3, created_at: 1.month.ago)

    expect { described_class.new(count: 5).call }.to output.to_stdout

    # Sender and recipient each get a copy; a draw of the same user twice is skipped.
    expect(Dmail.count).to be_between(0, 10)
    expect(Dmail.count).to be_even
  end
end
