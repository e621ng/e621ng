# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserMinimalBlueprint do
  subject(:result) { described_class.render_as_hash(user) }

  let(:user) { create(:user) }

  it "includes the expected keys" do
    expect(result.keys).to match_array(%i[id name level_string favorite_count])
  end

  it "serializes attribute values correctly" do
    expect(result).to include(
      id:             user.id,
      name:           user.name,
      level_string:   user.level_string,
      favorite_count: user.favorite_count,
    )
  end
end
