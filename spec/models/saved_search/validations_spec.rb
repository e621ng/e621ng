# frozen_string_literal: true

require "rails_helper"

RSpec.describe SavedSearch do
  include_context "as member"

  let(:user) { CurrentUser.user }

  describe "query normalization" do
    it "normalizes and sorts tags" do
      ss = create(:saved_search, user: user, query: "Fox  cat")
      expect(ss.query).to eq("cat fox")
    end

    it "preserves groups and quoted metatags verbatim (whitespace-squeezed)" do
      ss = create(:saved_search, user: user, query: "solo  ( fox cat )   description:\"two words\"")
      expect(ss.query).to eq('solo ( fox cat ) description:"two words"')
    end
  end

  describe "query validation" do
    it "rejects expanding wildcards" do
      ss = build(:saved_search, user: user, query: "fox_*")
      expect(ss).not_to be_valid
      expect(ss.errors[:query].join).to match(/wildcard/)
    end

    it "allows wildcard-value metatags" do
      expect(build(:saved_search, user: user, query: "source:*example*")).to be_valid
    end

    it "rejects search: references" do
      ss = build(:saved_search, user: user, query: "search:something")
      expect(ss).not_to be_valid
    end

    it "rejects queries over the reserved-slot tag budget" do
      query = (1..Danbooru.config.tag_query_limit).map { |n| "tag_#{n}" }.join(" ")
      ss = build(:saved_search, user: user, query: query)
      expect(ss).not_to be_valid
    end

    it "accepts queries at the saved-search tag budget" do
      query = (1..(Danbooru.config.tag_query_limit - 1)).map { |n| "tag_#{n}" }.join(" ")
      expect(build(:saved_search, user: user, query: query)).to be_valid
    end

    it "rejects blank queries" do
      expect(build(:saved_search, user: user, query: "")).not_to be_valid
    end

    it "rejects duplicate queries for the same user" do
      create(:saved_search, user: user, query: "fox cat")
      expect(build(:saved_search, user: user, query: "cat fox")).not_to be_valid
    end
  end

  describe "name validation" do
    it "slug-normalizes names" do
      ss = create(:saved_search, user: user, name: "My Search")
      expect(ss.name).to eq("my_search")
    end

    it "allows a missing name" do
      expect(build(:saved_search, user: user, name: nil)).to be_valid
    end

    it "rejects all-digit names so they never shadow search:<id>" do
      expect(build(:saved_search, user: user, name: "12345")).not_to be_valid
    end

    it "rejects duplicate names per user" do
      create(:saved_search, user: user, name: "dupe")
      expect(build(:saved_search, user: user, name: "dupe")).not_to be_valid
    end

    it "allows the same name for different users" do
      create(:saved_search, name: "shared_name")
      expect(build(:saved_search, user: user, name: "shared_name")).to be_valid
    end
  end

  describe "limits" do
    it "rejects creation past the saved search limit" do
      allow(Danbooru.config.custom_configuration).to receive(:saved_search_limit).and_return(2)
      create_list(:saved_search, 2, user: user)
      ss = build(:saved_search, user: user)
      expect(ss).not_to be_valid
      expect(ss.errors[:base].join).to match(/up to 2 saved searches/)
    end

    it "rejects tracking past the tracked limit" do
      allow(Danbooru.config.custom_configuration).to receive(:tracked_saved_search_limit).and_return(1)
      create(:saved_search, user: user, is_tracked: true)
      ss = build(:saved_search, user: user, is_tracked: true)
      expect(ss).not_to be_valid
      expect(ss.errors[:base].join).to match(/track up to 1/)
    end

    it "allows untracking at the tracked limit" do
      allow(Danbooru.config.custom_configuration).to receive(:tracked_saved_search_limit).and_return(1)
      ss = create(:saved_search, user: user, is_tracked: true)
      expect(ss.update(is_tracked: false)).to be(true)
    end
  end

  describe ".name_or_id_to_id" do
    let!(:saved_search) { create(:saved_search, user: user, name: "resolver_test") }

    it "resolves names and ids for the owner" do
      expect(SavedSearch.name_or_id_to_id("resolver_test", user)).to eq(saved_search.id)
      expect(SavedSearch.name_or_id_to_id(saved_search.id.to_s, user)).to eq(saved_search.id)
    end

    it "fails resolution for other users and anonymous" do
      expect(SavedSearch.name_or_id_to_id(saved_search.id.to_s, create(:user))).to be_nil
      expect(SavedSearch.name_or_id_to_id("resolver_test", User.anonymous)).to be_nil
    end
  end
end
