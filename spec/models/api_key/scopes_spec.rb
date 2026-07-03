# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                            ApiKey Scopes                                    #
# --------------------------------------------------------------------------- #

RSpec.describe ApiKey do
  include_context "as member"

  def make_api_key(overrides = {})
    create(:api_key, user: CurrentUser.user, **overrides)
  end

  # -------------------------------------------------------------------------
  # .for_user
  # -------------------------------------------------------------------------
  describe ".for_user" do
    let(:other_user) { create(:user) }
    let!(:own_key)   { make_api_key }
    let!(:other_key) { create(:api_key, user: other_user) }

    it "returns keys belonging to the given user_id" do
      expect(ApiKey.for_user(CurrentUser.user.id)).to include(own_key)
    end

    it "excludes keys belonging to other users" do
      expect(ApiKey.for_user(CurrentUser.user.id)).not_to include(other_key)
    end
  end

  # -------------------------------------------------------------------------
  # .active
  # -------------------------------------------------------------------------
  describe ".active" do
    let!(:no_expiry_key)     { make_api_key }
    let!(:future_expiry_key) { make_api_key(expires_at: 7.days.from_now) }
    let!(:past_expiry_key) do
      k = make_api_key
      k.update_columns(expires_at: 1.day.ago)
      k
    end

    it "includes keys with no expiry (expires_at IS NULL)" do
      expect(ApiKey.active).to include(no_expiry_key)
    end

    it "includes keys whose expires_at is in the future" do
      expect(ApiKey.active).to include(future_expiry_key)
    end

    it "excludes keys whose expires_at is in the past" do
      expect(ApiKey.active).not_to include(past_expiry_key)
    end
  end

  # -------------------------------------------------------------------------
  # .expired
  # -------------------------------------------------------------------------
  describe ".expired" do
    let!(:no_expiry_key)     { make_api_key }
    let!(:future_expiry_key) { make_api_key(expires_at: 7.days.from_now) }
    let!(:past_expiry_key) do
      k = make_api_key
      k.update_columns(expires_at: 1.day.ago)
      k
    end

    it "includes keys whose expires_at is in the past" do
      expect(ApiKey.expired).to include(past_expiry_key)
    end

    it "excludes keys with no expiry (expires_at IS NULL)" do
      expect(ApiKey.expired).not_to include(no_expiry_key)
    end

    it "excludes keys whose expires_at is in the future" do
      expect(ApiKey.expired).not_to include(future_expiry_key)
    end
  end

  # -------------------------------------------------------------------------
  # .expiring_soon
  # Window: expires_at between Time.current and 7.days.from_now, notified_at IS NULL
  # -------------------------------------------------------------------------
  describe ".expiring_soon" do
    let!(:expiring_soon_key) do
      create(:expiring_soon_api_key, user: CurrentUser.user)
    end

    let!(:already_notified_key) do
      k = make_api_key(expires_at: 5.days.from_now)
      k.update_columns(notified_at: 1.day.ago)
      k
    end

    let!(:no_expiry_key) { make_api_key }

    let!(:far_future_key) { make_api_key(expires_at: 14.days.from_now) }

    let!(:expired_key) do
      k = make_api_key
      k.update_columns(expires_at: 1.day.ago)
      k
    end

    it "includes keys expiring within 7 days when notified_at is nil" do
      expect(ApiKey.expiring_soon).to include(expiring_soon_key)
    end

    it "excludes keys expiring within 7 days when notified_at is already set" do
      expect(ApiKey.expiring_soon).not_to include(already_notified_key)
    end

    it "excludes keys with no expiry" do
      expect(ApiKey.expiring_soon).not_to include(no_expiry_key)
    end

    it "excludes keys expiring more than 7 days from now" do
      expect(ApiKey.expiring_soon).not_to include(far_future_key)
    end

    it "excludes keys that have already expired" do
      expect(ApiKey.expiring_soon).not_to include(expired_key)
    end
  end
end
