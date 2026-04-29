# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                              User::NameMethods                              #
# --------------------------------------------------------------------------- #

RSpec.describe User do
  describe "name methods" do
    # -------------------------------------------------------------------------
    # .normalize_name
    # -------------------------------------------------------------------------
    describe ".normalize_name" do
      it "converts to lowercase" do
        expect(User.normalize_name("TestUser")).to eq("testuser")
      end

      it "strips surrounding whitespace" do
        expect(User.normalize_name("  test  ")).to eq("test")
      end

      it "replaces spaces with underscores" do
        expect(User.normalize_name("test user")).to eq("test_user")
      end

      it "returns an empty string when given nil" do
        expect(User.normalize_name(nil)).to eq("")
      end
    end

    # -------------------------------------------------------------------------
    # .name_to_id
    # -------------------------------------------------------------------------
    describe ".name_to_id" do
      it "returns the user's ID when given their name" do
        user = create(:user)
        expect(User.name_to_id(user.name)).to eq(user.id)
      end

      it "is case-insensitive" do
        user = create(:user, name: "Testuser")
        expect(User.name_to_id("TESTUSER")).to eq(user.id)
        expect(User.name_to_id("testuser")).to eq(user.id)
      end

      it "treats spaces in the name as underscores" do
        user = create(:user, name: "test_user")
        expect(User.name_to_id("test user")).to eq(user.id)
      end

      it "returns nil when no user has the given name" do
        expect(User.name_to_id("nonexistent_user")).to be_nil
      end
    end

    # -------------------------------------------------------------------------
    # .name_or_id_to_id
    # -------------------------------------------------------------------------
    describe ".name_or_id_to_id" do
      it "returns the user's ID when given their name" do
        user = create(:user)
        expect(User.name_or_id_to_id(user.name)).to eq(user.id)
      end

      it "returns nil when no user has the given name" do
        expect(User.name_or_id_to_id("nonexistent_user")).to be_nil
      end

      it "returns the numeric ID when given !<id>" do
        user = create(:user)
        expect(User.name_or_id_to_id("!#{user.id}")).to eq(user.id)
      end

      it "does not treat a plain numeric string as an ID" do
        user = create(:user)
        # A bare number is treated as a name lookup, not an ID
        expect(User.name_or_id_to_id(user.id.to_s)).to be_nil
      end
    end

    # -------------------------------------------------------------------------
    # .name_or_id_to_id_forced
    # -------------------------------------------------------------------------
    describe ".name_or_id_to_id_forced" do
      it "returns the user's ID when given their name" do
        user = create(:user)
        expect(User.name_or_id_to_id_forced(user.name)).to eq(user.id)
      end

      it "returns nil when no user has the given name" do
        expect(User.name_or_id_to_id_forced("nonexistent_user")).to be_nil
      end

      it "returns the numeric ID when given a plain numeric string" do
        user = create(:user)
        expect(User.name_or_id_to_id_forced(user.id.to_s)).to eq(user.id)
      end

      it "does not treat a !<id> string as an ID" do
        user = create(:user)
        # The !<id> prefix is not recognised here; falls back to name lookup
        expect(User.name_or_id_to_id_forced("!#{user.id}")).to be_nil
      end
    end

    # -------------------------------------------------------------------------
    # .id_to_name
    # -------------------------------------------------------------------------
    describe ".id_to_name" do
      it "returns the user's name when given their ID" do
        user = create(:user)
        expect(User.id_to_name(user.id)).to eq(user.name)
      end

      it "returns the default guest name when no user has the given ID" do
        expect(User.id_to_name(0)).to eq(Danbooru.config.default_guest_name)
      end
    end

    # -------------------------------------------------------------------------
    # .find_by_name
    # -------------------------------------------------------------------------
    describe ".find_by_name" do
      it "returns the user when found" do
        user = create(:user)
        expect(User.find_by_name(user.name)).to eq(user) # rubocop:disable Rails/DynamicFindBy
      end

      it "is case-insensitive" do
        user = create(:user, name: "Testuser")
        expect(User.find_by_name("TESTUSER")).to eq(user) # rubocop:disable Rails/DynamicFindBy
        expect(User.find_by_name("testuser")).to eq(user) # rubocop:disable Rails/DynamicFindBy
      end

      it "returns nil when no user has the given name" do
        expect(User.find_by_name("nonexistent_user")).to be_nil # rubocop:disable Rails/DynamicFindBy
      end
    end

    # -------------------------------------------------------------------------
    # .find_by_name_or_id
    # -------------------------------------------------------------------------
    describe ".find_by_name_or_id" do
      it "returns the user when given their name" do
        user = create(:user)
        expect(User.find_by_name_or_id(user.name)).to eq(user) # rubocop:disable Rails/DynamicFindBy
      end

      it "returns the user when given !<id>" do
        user = create(:user)
        expect(User.find_by_name_or_id("!#{user.id}")).to eq(user) # rubocop:disable Rails/DynamicFindBy
      end

      it "returns nil when no user has the given name" do
        expect(User.find_by_name_or_id("nonexistent_user")).to be_nil # rubocop:disable Rails/DynamicFindBy
      end

      it "returns nil when given !<id> with no matching user" do
        expect(User.find_by_name_or_id("!0")).to be_nil # rubocop:disable Rails/DynamicFindBy
      end
    end

    # -------------------------------------------------------------------------
    # #pretty_name
    # -------------------------------------------------------------------------
    describe "#pretty_name" do
      it "replaces single underscores with spaces" do
        user = build(:user, name: "test_user")
        expect(user.pretty_name).to eq("test user")
      end

      it "does not alter names without underscores" do
        user = build(:user, name: "testuser")
        expect(user.pretty_name).to eq("testuser")
      end

      it "collapses consecutive underscores into a single space" do
        user = build(:user, name: "test__user")
        expect(user.pretty_name).to eq("test user")
      end
    end

    # -------------------------------------------------------------------------
    # #update_cache
    # -------------------------------------------------------------------------
    describe "#update_cache" do
      it "populates the id-to-name cache entry" do
        user = create(:user)
        user.update_cache
        expect(Cache.fetch("uin:#{user.id}")).to eq(user.name)
      end

      it "populates the name-to-id cache entry" do
        user = create(:user)
        user.update_cache
        expect(Cache.fetch("uni:#{User.normalize_name(user.name)}")).to eq(user.id)
      end
    end
  end
end
