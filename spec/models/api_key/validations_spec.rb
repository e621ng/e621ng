# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          ApiKey Validations                                 #
# --------------------------------------------------------------------------- #

RSpec.describe ApiKey do
  # -------------------------------------------------------------------------
  # name — presence
  # -------------------------------------------------------------------------
  describe "name — presence" do
    include_context "as member"

    it "is invalid with an empty name" do
      key = build(:api_key, name: "")
      expect(key).not_to be_valid
      expect(key.errors[:name]).to be_present
    end

    it "is invalid with a nil name" do
      key = build(:api_key, name: nil)
      expect(key).not_to be_valid
      expect(key.errors[:name]).to be_present
    end

    it "is valid with a present name" do
      key = build(:api_key, name: "My Key")
      expect(key).to be_valid, key.errors.full_messages.join(", ")
    end
  end

  # -------------------------------------------------------------------------
  # name — uniqueness scoped to user_id
  # -------------------------------------------------------------------------
  describe "name — uniqueness scoped to user_id" do
    include_context "as member"

    it "is invalid when the same user already has a key with that name" do
      create(:api_key, user: CurrentUser.user, name: "Duplicate")
      key = build(:api_key, user: CurrentUser.user, name: "Duplicate")
      expect(key).not_to be_valid
      expect(key.errors[:name]).to be_present
    end

    it "is valid when a different user has a key with the same name" do
      other_user = create(:user)
      create(:api_key, user: other_user, name: "Shared Name")
      key = build(:api_key, user: CurrentUser.user, name: "Shared Name")
      expect(key).to be_valid, key.errors.full_messages.join(", ")
    end
  end

  # -------------------------------------------------------------------------
  # expires_at — validate_expiration_date (guard: if: :expires_at?)
  # -------------------------------------------------------------------------
  describe "expires_at — validate_expiration_date" do
    include_context "as member"

    it "is valid when expires_at is nil (guard skips the validator)" do
      key = build(:api_key, expires_at: nil)
      expect(key).to be_valid, key.errors.full_messages.join(", ")
    end

    it "is valid when expires_at is in the future" do
      key = build(:api_key, expires_at: 1.day.from_now)
      expect(key).to be_valid, key.errors.full_messages.join(", ")
    end

    it "is invalid when expires_at is in the past" do
      key = build(:api_key, expires_at: 1.second.ago)
      expect(key).not_to be_valid
      expect(key.errors[:expires_at]).to include("must be in the future")
    end

    it "is invalid when expires_at equals Time.current (boundary: <= comparison)" do
      frozen = Time.current
      allow(Time).to receive(:current).and_return(frozen)
      key = build(:api_key, expires_at: frozen)
      expect(key).not_to be_valid
      expect(key.errors[:expires_at]).to include("must be in the future")
    end
  end

  # -------------------------------------------------------------------------
  # validate_api_key_limit — on: :create
  # -------------------------------------------------------------------------
  describe "validate_api_key_limit — on: :create" do
    # This validator calls user.api_keys.size (live DB count), so all
    # pre-existing keys must be created (not built) in the DB.

    describe "regular user (limit: 5)" do
      include_context "as member"

      it "is valid when the user is below their limit" do
        create_list(:api_key, 4, user: CurrentUser.user)
        key = build(:api_key, user: CurrentUser.user)
        expect(key).to be_valid, key.errors.full_messages.join(", ")
      end

      it "is invalid on create when the user has reached their limit" do
        create_list(:api_key, 5, user: CurrentUser.user)
        expect do
          ApiKey.generate!(CurrentUser.user, name: "over_limit")
        end.to raise_error(ActiveRecord::RecordInvalid, /API key limit reached/)
      end

      it "does not run on update (a key at-limit can still be saved)" do
        create_list(:api_key, 5, user: CurrentUser.user)
        existing_key = ApiKey.for_user(CurrentUser.user.id).first
        existing_key.name = "Updated Name"
        expect(existing_key).to be_valid, existing_key.errors.full_messages.join(", ")
      end
    end

    describe "privileged user (limit: 10)" do
      include_context "as privileged"

      it "is invalid on create when the privileged user has reached their limit of 10" do
        create_list(:api_key, 10, user: CurrentUser.user)
        expect do
          ApiKey.generate!(CurrentUser.user, name: "over_limit")
        end.to raise_error(ActiveRecord::RecordInvalid, /API key limit reached/)
      end

      it "is still valid when the privileged user has 9 keys (below limit)" do
        create_list(:api_key, 9, user: CurrentUser.user)
        key = build(:api_key, user: CurrentUser.user)
        expect(key).to be_valid, key.errors.full_messages.join(", ")
      end
    end

    describe "staff / janitor (limit: 20)" do
      include_context "as janitor"

      it "is invalid on create when the janitor has reached their limit of 20" do
        create_list(:api_key, 20, user: CurrentUser.user)
        expect do
          ApiKey.generate!(CurrentUser.user, name: "over_limit")
        end.to raise_error(ActiveRecord::RecordInvalid, /API key limit reached/)
      end

      it "is still valid when the janitor has 19 keys (below limit)" do
        create_list(:api_key, 19, user: CurrentUser.user)
        key = build(:api_key, user: CurrentUser.user)
        expect(key).to be_valid, key.errors.full_messages.join(", ")
      end
    end
  end

  # -------------------------------------------------------------------------
  # key — uniqueness
  # -------------------------------------------------------------------------
  # has_secure_token generates a unique 24-char base58 token on every create,
  # making a real collision not reproducible in tests. This validation exists
  # as a DB-level safety net and is intentionally not tested here.
end
