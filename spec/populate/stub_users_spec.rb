# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/populate")

RSpec.describe Populate::StubUsers do
  include_context "as admin"

  it "creates placeholder users for missing ids only" do
    existing = create(:user)

    created = described_class.new(ids: [existing.id, 900_001, 900_001]).call

    expect(created).to eq(1)
    stub = User.find(900_001)
    expect(stub.name).to eq("user_900001")
    expect(stub.user_status).to be_present
    expect(User.authenticate(stub.name, Populate::DEFAULT_PASSWORD)).to eq(stub)
    expect(ActiveRecord::Base.connection.select_value("SELECT nextval('users_id_seq')").to_i).to eq(900_002)
  end

  it "does nothing for an empty list" do
    expect(described_class.new(ids: []).call).to eq(0)
  end
end
