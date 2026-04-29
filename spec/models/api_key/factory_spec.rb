# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           ApiKey Factory                                    #
# --------------------------------------------------------------------------- #

RSpec.describe ApiKey do
  include_context "as member"

  describe "factory" do
    it "produces a valid api_key with build" do
      key = build(:api_key)
      expect(key).to be_valid, key.errors.full_messages.join(", ")
    end

    it "produces a valid api_key with create, persisting the record" do
      expect(create(:api_key)).to be_persisted
    end

    it "generates a non-blank key token on create" do
      key = create(:api_key)
      expect(key.key).to be_present
    end

    it "produces a valid :expiring_api_key with a future expires_at" do
      key = create(:expiring_api_key)
      expect(key).to be_persisted
      expect(key.expires_at).to be > Time.current
    end

    it "produces an :expired_api_key whose expires_at is in the past" do
      key = create(:expired_api_key)
      expect(key).to be_persisted
      expect(key.expires_at).to be < Time.current
    end
  end
end
