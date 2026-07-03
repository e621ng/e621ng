# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        ArtistUrl Factory Sanity Checks                      #
# --------------------------------------------------------------------------- #

RSpec.describe ArtistUrl do
  include_context "as admin"

  describe "factory" do
    it "produces a valid artist_url with build" do
      record = build(:artist_url)
      expect(record).to be_valid, record.errors.full_messages.join(", ")
    end

    it "produces a valid artist_url with create" do
      expect(create(:artist_url)).to be_persisted
    end

    it "produces a valid inactive_artist_url" do
      record = create(:inactive_artist_url)
      expect(record).to be_persisted
      expect(record.is_active).to be false
    end
  end
end
