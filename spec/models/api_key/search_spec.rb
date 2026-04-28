# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         ApiKey Search & Visible                             #
# --------------------------------------------------------------------------- #

RSpec.describe ApiKey do
  include_context "as member"

  def make_api_key(overrides = {})
    create(:api_key, user: CurrentUser.user, **overrides)
  end

  let(:other_user) { create(:user) }
  let!(:key_alpha) { make_api_key(name: "Alpha Key") }
  let!(:key_beta)  { make_api_key(name: "Beta Key") }
  let!(:key_other) { create(:api_key, user: other_user) }

  # -------------------------------------------------------------------------
  # .visible
  # -------------------------------------------------------------------------
  describe ".visible" do
    it "returns only keys belonging to the given user" do
      result = ApiKey.visible(CurrentUser.user)
      expect(result).to include(key_alpha, key_beta)
    end

    it "excludes keys belonging to other users" do
      result = ApiKey.visible(CurrentUser.user)
      expect(result).not_to include(key_other)
    end
  end

  # -------------------------------------------------------------------------
  # .search — name_matches param
  # -------------------------------------------------------------------------
  describe "name_matches param" do
    it "returns keys whose name matches exactly" do
      result = ApiKey.search(name_matches: "Alpha Key")
      expect(result).to include(key_alpha)
      expect(result).not_to include(key_beta)
    end

    it "supports a trailing wildcard pattern" do
      result = ApiKey.search(name_matches: "Alpha*")
      expect(result).to include(key_alpha)
      expect(result).not_to include(key_beta)
    end

    it "returns all keys when name_matches is absent" do
      result = ApiKey.search({})
      expect(result).to include(key_alpha, key_beta)
    end
  end

  # -------------------------------------------------------------------------
  # .search — user_name / user_id param (via where_user)
  # -------------------------------------------------------------------------
  describe "user_name param" do
    it "returns only keys for the named user" do
      result = ApiKey.search(user_name: CurrentUser.user.name)
      expect(result).to include(key_alpha, key_beta)
      expect(result).not_to include(key_other)
    end

    it "excludes keys for other users" do
      result = ApiKey.search(user_name: other_user.name)
      expect(result).to include(key_other)
      expect(result).not_to include(key_alpha)
    end

    it "returns all keys when user_name is absent" do
      result = ApiKey.search({})
      expect(result).to include(key_alpha, key_beta, key_other)
    end
  end

  # -------------------------------------------------------------------------
  # .search — is_expired param
  # -------------------------------------------------------------------------
  describe "is_expired param" do
    let!(:active_key) { make_api_key(name: "Active Key") }
    let!(:expired_key) do
      k = make_api_key(name: "Expired Key")
      k.update_columns(expires_at: 1.day.ago)
      k
    end

    it "returns only expired keys when is_expired is '1'" do
      result = ApiKey.search(is_expired: "1")
      expect(result).to include(expired_key)
      expect(result).not_to include(active_key)
    end

    it "returns only expired keys when is_expired is 'true'" do
      result = ApiKey.search(is_expired: "true")
      expect(result).to include(expired_key)
      expect(result).not_to include(active_key)
    end

    it "returns only active keys when is_expired is '0'" do
      result = ApiKey.search(is_expired: "0")
      expect(result).to include(active_key)
      expect(result).not_to include(expired_key)
    end

    it "returns only active keys when is_expired is 'false'" do
      result = ApiKey.search(is_expired: "false")
      expect(result).to include(active_key)
      expect(result).not_to include(expired_key)
    end

    it "returns all keys when is_expired is absent" do
      result = ApiKey.search({})
      expect(result).to include(active_key, expired_key)
    end
  end

  # -------------------------------------------------------------------------
  # .search — order param
  # -------------------------------------------------------------------------
  describe "order param" do
    # Use a dedicated user to avoid hitting CurrentUser.user's 5-key limit.
    # The outer let! fixtures (key_alpha, key_beta) already consume 2 slots.
    let(:order_user) { create(:user) }

    def make_api_key(overrides = {})
      create(:api_key, user: order_user, **overrides)
    end

    before do
      make_api_key(name: "Aardvark")
      make_api_key(name: "Zebra")
    end

    it "orders by name ascending when order is 'name_asc'" do
      ids = ApiKey.search(order: "name_asc").pluck(:name)
      expect(ids.index("Aardvark")).to be < ids.index("Zebra")
    end

    it "orders by name descending when order is 'name_desc'" do
      ids = ApiKey.search(order: "name_desc").pluck(:name)
      expect(ids.index("Zebra")).to be < ids.index("Aardvark")
    end

    it "defaults to descending when no direction suffix is given (name)" do
      ids = ApiKey.search(order: "name").pluck(:name)
      expect(ids.index("Zebra")).to be < ids.index("Aardvark")
    end

    it "orders by expires_at ascending when order is 'expires_at_asc'" do
      user = create(:user)
      sooner = make_api_key(name: "Sooner", user: user, expires_at: 5.days.from_now)
      later  = make_api_key(name: "Later", user: user,  expires_at: 10.days.from_now)
      # keys with nil expires_at will appear at the end in ascending postgres NULL handling
      ids = ApiKey.search(user_id: user.id, order: "expires_at_asc").ids
      expect(ids.index(sooner.id)).to be < ids.index(later.id)
    end

    it "orders by last_used_at descending when order is 'last_used_at_desc'" do
      user = create(:user)
      earlier = make_api_key(name: "Earlier", user: user)
      later   = make_api_key(name: "Later", user: user)
      earlier.update_columns(last_used_at: 2.hours.ago)
      later.update_columns(last_used_at: 1.hour.ago)
      ids = ApiKey.search(user_id: user.id, order: "last_used_at_desc").ids
      expect(ids.index(later.id)).to be < ids.index(earlier.id)
    end

    it "does not raise for an unrecognized order string" do
      expect { ApiKey.search(order: "nonsense").to_a }.not_to raise_error
    end

    it "applies secondary id: :desc ordering to break ties" do
      # Two keys with the same name owned by different users (name is unique per user).
      # The one created later (higher id) should come first when ordering by name desc
      # (they tie on name, secondary sort is id desc).
      first_created  = create(:api_key, user: other_user, name: "Same Name")
      second_created = make_api_key(name: "Same Name")
      ids = ApiKey.search(order: "name_desc").ids
      expect(ids.index(second_created.id)).to be < ids.index(first_created.id)
    end
  end
end
