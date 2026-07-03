# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          Pool Search & Scopes                               #
# --------------------------------------------------------------------------- #

RSpec.describe Pool do
  include_context "as admin"

  def make_pool(overrides = {})
    create(:pool, **overrides)
  end

  # -------------------------------------------------------------------------
  # Shared fixtures
  # -------------------------------------------------------------------------
  let!(:series_pool)     { make_pool(name: "search_series_alpha",    category: "series",     description: "has the word dolphin", is_active: true) }
  let!(:collection_pool) { make_pool(name: "search_collection_beta", category: "collection", description: "nothing special",      is_active: false) }
  let!(:other_pool)      { make_pool(name: "unrelated_pool",         category: "series",     description: "unrelated",            is_active: true) }

  # -------------------------------------------------------------------------
  # .search — name_matches param
  # -------------------------------------------------------------------------
  describe "name_matches param" do
    it "returns pools whose name matches exactly" do
      result = Pool.search(name_matches: "search_series_alpha")
      expect(result).to include(series_pool)
      expect(result).not_to include(other_pool)
    end

    it "supports a trailing wildcard" do
      result = Pool.search(name_matches: "search_*")
      expect(result).to include(series_pool, collection_pool)
      expect(result).not_to include(other_pool)
    end

    it "is case-insensitive" do
      result = Pool.search(name_matches: "SEARCH_SERIES_ALPHA")
      expect(result).to include(series_pool)
    end

    it "converts spaces to underscores before matching" do
      result = Pool.search(name_matches: "search series alpha")
      expect(result).to include(series_pool)
    end

    it "returns all pools when name_matches is absent" do
      result = Pool.search({})
      expect(result).to include(series_pool, collection_pool, other_pool)
    end
  end

  # -------------------------------------------------------------------------
  # .search — description_matches param
  # -------------------------------------------------------------------------
  describe "description_matches param" do
    it "returns pools whose description matches the search term" do
      result = Pool.search(description_matches: "dolphin")
      expect(result).to include(series_pool)
      expect(result).not_to include(collection_pool)
    end

    it "returns all pools when description_matches is absent" do
      result = Pool.search({})
      expect(result).to include(series_pool, collection_pool)
    end
  end

  # -------------------------------------------------------------------------
  # .search — category param
  # -------------------------------------------------------------------------
  describe "category param" do
    it "returns only series pools when category is 'series'" do
      result = Pool.search(category: "series")
      expect(result).to include(series_pool, other_pool)
      expect(result).not_to include(collection_pool)
    end

    it "returns only collection pools when category is 'collection'" do
      result = Pool.search(category: "collection")
      expect(result).to include(collection_pool)
      expect(result).not_to include(series_pool)
    end

    it "returns all pools when category is absent" do
      result = Pool.search({})
      expect(result).to include(series_pool, collection_pool)
    end
  end

  # -------------------------------------------------------------------------
  # .search — is_active param
  # -------------------------------------------------------------------------
  describe "is_active param" do
    it "returns only active pools when is_active is 'true'" do
      result = Pool.search(is_active: "true")
      expect(result).to include(series_pool, other_pool)
      expect(result).not_to include(collection_pool)
    end

    it "returns only inactive pools when is_active is 'false'" do
      result = Pool.search(is_active: "false")
      expect(result).to include(collection_pool)
      expect(result).not_to include(series_pool)
    end
  end

  # -------------------------------------------------------------------------
  # .search — creator param
  # -------------------------------------------------------------------------
  describe "creator param" do
    it "returns pools created by a specific user" do
      other_user = create(:admin_user)
      other_pool_by_user = CurrentUser.scoped(other_user, "127.0.0.1") { make_pool(name: "creator_specific_pool") }

      result = Pool.search({ "creator_name" => other_user.name })
      expect(result).to include(other_pool_by_user)
      expect(result).not_to include(series_pool)
    end
  end

  # -------------------------------------------------------------------------
  # .search — order param
  # -------------------------------------------------------------------------
  describe "order param" do
    it "orders by name ascending when order is 'name'" do
      result = Pool.search(order: "name").to_a
      names = result.map(&:name)
      expect(names).to eq(names.sort)
    end

    it "orders by created_at descending when order is 'created_at'" do
      result = Pool.search(order: "created_at").to_a
      timestamps = result.map(&:created_at)
      expect(timestamps).to eq(timestamps.sort.reverse)
    end

    it "orders by post_count descending when order is 'post_count'" do
      posts = create_list(:post, 4)
      pool_small = make_pool(name: "order_small_pool", post_ids: [posts[0].id])
      pool_large = make_pool(name: "order_large_pool", post_ids: posts[1..3].map(&:id))

      result = Pool.search(order: "post_count").to_a
      large_index = result.index(pool_large)
      small_index = result.index(pool_small)
      expect(large_index).to be < small_index
    end
  end

  # -------------------------------------------------------------------------
  # Scopes
  # -------------------------------------------------------------------------
  describe ".for_user" do
    it "returns pools created by the given user" do
      user = create(:admin_user)
      pool = CurrentUser.scoped(user) { make_pool(name: "for_user_pool") }
      expect(Pool.for_user(user.id)).to include(pool)
      expect(Pool.for_user(user.id)).not_to include(series_pool)
    end
  end

  describe ".series" do
    it "returns only series-category pools" do
      expect(Pool.series).to include(series_pool, other_pool)
      expect(Pool.series).not_to include(collection_pool)
    end
  end

  describe ".collection" do
    it "returns only collection-category pools" do
      expect(Pool.collection).to include(collection_pool)
      expect(Pool.collection).not_to include(series_pool)
    end
  end

  describe ".series_first" do
    it "orders series pools before collection pools" do
      result = Pool.series_first.to_a
      series_indices     = result.each_with_index.select { |p, _| p.category == "series"     }.map(&:last)
      collection_indices = result.each_with_index.select { |p, _| p.category == "collection" }.map(&:last)
      expect(series_indices.max).to be < collection_indices.min
    end
  end

  describe ".selected_first" do
    it "returns the selected pool first" do
      result = Pool.selected_first(series_pool.id).to_a
      expect(result.first).to eq(series_pool)
    end

    it "returns all pools when current_pool_id is blank" do
      result = Pool.selected_first(nil)
      expect(result).to include(series_pool, collection_pool, other_pool)
    end
  end

  describe ".default_order" do
    it "orders by updated_at descending" do
      result = Pool.default_order.to_a
      timestamps = result.map(&:updated_at)
      expect(timestamps).to eq(timestamps.sort.reverse)
    end
  end
end
