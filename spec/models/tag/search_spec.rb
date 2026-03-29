# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          Tag Search & Scopes                                #
# --------------------------------------------------------------------------- #

RSpec.describe Tag do
  include_context "as admin"
  include_context "with tag categories"

  # Shared tag fixtures reused across groups.
  let!(:general_tag)  { create(:tag, name: "search_general",   category: general_tag_category,   post_count: 10) }
  let!(:artist_tag)   { create(:tag, name: "search_artist",    category: artist_tag_category,    post_count: 5)  }
  let!(:empty_tag)    { create(:tag, name: "search_empty",     category: general_tag_category,   post_count: 0)  }
  let!(:locked_tag)   { create(:tag, name: "search_locked",    category: general_tag_category,   post_count: 3,  is_locked: true) }
  let!(:meta_tag)     { create(:tag, name: "search_meta",      category: meta_tag_category,      post_count: 7)  }

  # -------------------------------------------------------------------------
  # Scopes: .empty / .nonempty
  # -------------------------------------------------------------------------
  describe ".empty" do
    it "returns only tags with post_count <= 0" do
      result = Tag.empty
      expect(result).to include(empty_tag)
      expect(result).not_to include(general_tag, artist_tag)
    end
  end

  describe ".nonempty" do
    it "returns only tags with post_count > 0" do
      result = Tag.nonempty
      expect(result).to include(general_tag, artist_tag)
      expect(result).not_to include(empty_tag)
    end
  end

  # -------------------------------------------------------------------------
  # .name_matches
  # -------------------------------------------------------------------------
  describe ".name_matches" do
    it "returns a tag that exactly matches the name" do
      expect(Tag.name_matches("search_general")).to include(general_tag)
    end

    it "supports a trailing wildcard" do
      result = Tag.name_matches("search_*")
      names = result.map(&:name)
      expect(names).to include("search_general", "search_artist", "search_empty")
    end

    it "is case-insensitive (normalizes before matching)" do
      expect(Tag.name_matches("SEARCH_GENERAL")).to include(general_tag)
    end

    it "does not return unrelated tags" do
      unrelated = create(:tag, name: "completely_different", post_count: 1)
      expect(Tag.name_matches("search_*")).not_to include(unrelated)
    end
  end

  # -------------------------------------------------------------------------
  # .search
  # -------------------------------------------------------------------------
  describe ".search" do
    describe "name_matches param" do
      it "filters by name pattern" do
        result = Tag.search(name_matches: "search_general")
        expect(result).to include(general_tag)
        expect(result).not_to include(artist_tag)
      end
    end

    describe "name param (exact comma-separated list)" do
      it "returns only the named tags" do
        result = Tag.search(name: "search_general,search_artist", hide_empty: false)
        expect(result).to include(general_tag, artist_tag)
        expect(result).not_to include(empty_tag)
      end
    end

    describe "category param" do
      it "filters by category ID" do
        result = Tag.search(category: artist_tag_category.to_s, hide_empty: false)
        expect(result).to include(artist_tag)
        expect(result).not_to include(general_tag)
      end

      it "accepts multiple comma-separated category IDs" do
        result = Tag.search(
          category: "#{general_tag_category},#{artist_tag_category}",
          hide_empty: false,
        )
        expect(result).to include(general_tag, artist_tag)
        expect(result).not_to include(meta_tag)
      end
    end

    describe "hide_empty param" do
      it "excludes zero-count tags by default" do
        result = Tag.search(name_matches: "search_*")
        expect(result).not_to include(empty_tag)
      end

      it "includes zero-count tags when hide_empty is false" do
        result = Tag.search(name_matches: "search_*", hide_empty: false)
        expect(result).to include(empty_tag)
      end
    end

    describe "is_locked param" do
      it "returns only locked tags when is_locked is 'true'" do
        result = Tag.search(name_matches: "search_*", is_locked: "true")
        expect(result).to include(locked_tag)
        expect(result).not_to include(general_tag)
      end

      it "returns only unlocked tags when is_locked is 'false'" do
        result = Tag.search(name_matches: "search_*", is_locked: "false")
        expect(result).not_to include(locked_tag)
        expect(result).to include(general_tag)
      end
    end

    describe "order param" do
      it "orders by name ascending when order is 'name'" do
        result = Tag.search(name_matches: "search_*", order: "name").map(&:name)
        expect(result).to eq(result.sort)
      end

      it "orders by id ascending when order is 'id_asc'" do
        result = Tag.search(name_matches: "search_*", order: "id_asc").map(&:id)
        expect(result).to eq(result.sort)
      end

      it "orders by id descending when order is 'id_desc'" do
        result = Tag.search(name_matches: "search_*", order: "id_desc").map(&:id)
        expect(result).to eq(result.sort.reverse)
      end

      it "orders by post_count descending by default" do
        result = Tag.search(name_matches: "search_*").map(&:post_count)
        expect(result).to eq(result.sort.reverse)
      end
    end
  end
end
