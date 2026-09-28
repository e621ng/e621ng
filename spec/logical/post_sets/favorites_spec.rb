# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostSets::Favorites do
  include_context "as member"

  let(:user) { create(:user) }
  let(:folder) { create(:favorite_folder, user: user) }

  # Files a freshly favorited post into the folder with an explicit favorite_created_at.
  # Called in increasing `days` order below, so membership-row insertion order (and
  # therefore id order) runs OLDEST-favorite_created_at-last - the exact inverse of the
  # correct favorite_created_at desc display order. This is deliberate: it's the one
  # fixture shape that makes an accidental fall-back to id ordering produce a visibly
  # wrong (reversed) result instead of coincidentally matching the correct one.
  def file_post!(days_ago:)
    post = create(:post)
    favorite = Favorite.create!(user: user, post: post, created_at: days_ago.days.ago)
    create(:favorite_folder_membership, user: user, folder: folder, favorite: favorite)
    favorite
  end

  describe "#posts inside a folder" do
    it "orders by favorite_created_at desc, not membership row insertion/id order" do
      favorites = (1..5).map { |days| file_post!(days_ago: days) } # id 1 = newest .. id 5 = oldest

      set = PostSets::Favorites.new(user, "1", limit: 40, folder_scoped: true, folder: folder)
      expect(set.posts.map(&:id)).to eq(favorites.map(&:post_id))
    end

    it "breaks favorite_created_at ties deterministically by favorite_id desc" do
      tie_time = 1.day.ago
      first_favorite = Favorite.create!(user: user, post: create(:post), created_at: tie_time)
      second_favorite = Favorite.create!(user: user, post: create(:post), created_at: tie_time)
      create(:favorite_folder_membership, user: user, folder: folder, favorite: first_favorite)
      create(:favorite_folder_membership, user: user, folder: folder, favorite: second_favorite)

      set = PostSets::Favorites.new(user, "1", limit: 40, folder_scoped: true, folder: folder)
      expect(set.posts.map(&:id)).to eq([second_favorite.post_id, first_favorite.post_id])
    end
  end

  describe "#posts at root (folder_scoped, folder: nil) - true folder semantics" do
    it "excludes a favorite that has been filed into a folder" do
      filed = file_post!(days_ago: 1)

      set = PostSets::Favorites.new(user, "1", limit: 40, folder_scoped: true, folder: nil)
      expect(set.posts.map(&:id)).not_to include(filed.post_id)
    end

    it "includes a favorite that has never been filed into any folder" do
      post = create(:post)
      unfiled = Favorite.create!(user: user, post: post)

      set = PostSets::Favorites.new(user, "1", limit: 40, folder_scoped: true, folder: nil)
      expect(set.posts.map(&:id)).to include(unfiled.post_id)
    end

    it "shows a favorite again at root once it's moved back out of every folder" do
      filed = file_post!(days_ago: 1)

      FavoriteFolderManager.move!(user: user, post: filed.post, destination_folder_id: nil)

      set = PostSets::Favorites.new(user, "1", limit: 40, folder_scoped: true, folder: nil)
      expect(set.posts.map(&:id)).to include(filed.post_id)
    end

    it "does not require any new column or index on favorites - the schema stays exactly as it was before this feature" do
      expect(Favorite.column_names).to match_array(%w[id user_id post_id created_at])
      # connection.indexes excludes the implicit primary key index (favorites_pkey).
      index_names = ActiveRecord::Base.connection.indexes(:favorites).map(&:name)
      expect(index_names).to match_array(%w[
        index_favorites_on_post_id
        index_favorites_on_user_id
        index_favorites_on_user_id_and_created_at
        index_favorites_on_user_id_and_id
        index_favorites_on_user_id_and_post_id
      ])
    end

    it "gives favorite_folder_memberships exactly its final index layout - no separate (user_id, folder_id, id) index, since folder pagination is numbered-only and never orders by this table's own id" do
      index_names = ActiveRecord::Base.connection.indexes(:favorite_folder_memberships).map(&:name)
      expect(index_names).to match_array(%w[
        index_favorite_folder_memberships_on_favorite_id
        index_favorite_folder_memberships_on_folder_id
        index_favorite_folder_memberships_user_folder_created_favorite
      ])
    end

    it "adds an extended-statistics object on (user_id, folder_id) covering dependencies and ndistinct - folder_id determines user_id 1:1, which Postgres cannot infer from single-column stats alone (Phase 5.5 measured a >500x row-count misestimate without it; see migration comment)" do
      # Checks the catalog OBJECT, not computed values (pg_statistic_ext_data) - the
      # object exists as soon as the migration runs, before any ANALYZE.
      columns = ActiveRecord::Base.connection.select_rows(<<~SQL.squish).flatten
        SELECT a.attname
        FROM pg_statistic_ext e
        JOIN pg_class c ON c.oid = e.stxrelid
        JOIN pg_attribute a ON a.attrelid = e.stxrelid AND a.attnum = ANY (e.stxkeys)
        WHERE e.stxname = 'statistics_ffm_user_folder' AND c.relname = 'favorite_folder_memberships'
      SQL
      expect(columns).to match_array(%w[user_id folder_id])

      # stxkind is a "char"[] (e.g. "{d,f}") - order is not guaranteed, so compare as a
      # set. d = ndistinct, f = dependencies (Postgres's internal single-char codes).
      stxkind = ActiveRecord::Base.connection.select_value(
        "SELECT stxkind::text FROM pg_statistic_ext WHERE stxname = 'statistics_ffm_user_folder'",
      )
      expect(stxkind.delete("{}").split(",")).to match_array(%w[d f])
    end
  end

  describe "#posts with a legacy id-based cursor token (the 'aXX'/'bXX' shape PaginatorComponent would emit for an ordinary numbered listing once current_page reaches Danbooru.config.max_numbered_pages)" do
    it "rejects a 'bXX' token outright with PaginationError, instead of translating it" do
      file_post!(days_ago: 1)
      set = PostSets::Favorites.new(user, "b1", limit: 2, folder_scoped: true, folder: folder)
      expect { set.posts }.to raise_error(Danbooru::Paginator::PaginationError)
    end

    it "rejects an 'aXX' token outright with PaginationError, instead of translating it" do
      file_post!(days_ago: 1)
      set = PostSets::Favorites.new(user, "a1", limit: 2, folder_scoped: true, folder: folder)
      expect { set.posts }.to raise_error(Danbooru::Paginator::PaginationError)
    end

    it "rejects a stale or foreign membership id in the token too - no silent fallback to page 1" do
      favorites = (1..5).map { |days| file_post!(days_ago: days) }

      set = PostSets::Favorites.new(user, "b999999999", limit: 2, folder_scoped: true, folder: folder)
      expect { set.posts }.to raise_error(Danbooru::Paginator::PaginationError)
      _ = favorites # only seeded to prove the folder has content the "fallback" would have shown
    end

    it "still raises Danbooru::Paginator::PaginationError for a genuinely malformed page param" do
      set = PostSets::Favorites.new(user, "not-a-page", limit: 2, folder_scoped: true, folder: folder)
      expect { set.posts }.to raise_error(Danbooru::Paginator::PaginationError)
    end
  end

  describe "#posts pagination metadata" do
    it "reports a max_numbered_pages strictly above the real Danbooru.config.max_numbered_pages ceiling, so PaginatorComponent never renders a cursor-mode link for a folder page" do
      allow(Danbooru.config.custom_configuration).to receive(:max_numbered_pages).and_return(5)
      file_post!(days_ago: 1)

      set = PostSets::Favorites.new(user, "1", limit: 2, folder_scoped: true, folder: folder)
      expect(set.posts.max_numbered_pages).to eq(6)
      expect(set.posts.pagination_mode).to eq(:numbered)
    end

    it "caps total_pages at the real ceiling (not the inflated max_numbered_pages) so is_last_page? - and so PaginatorComponent's has_next? - is correctly true at the last reachable page" do
      allow(Danbooru.config.custom_configuration).to receive(:max_numbered_pages).and_return(2)
      3.times { |i| file_post!(days_ago: 3 - i) }

      set = PostSets::Favorites.new(user, "2", limit: 1, folder_scoped: true, folder: folder)
      posts = set.posts
      expect(posts.total_pages).to eq(2)
      expect(posts.is_last_page?).to be true
    end

    it "keeps total_count capped at the pagination ceiling while separately exposing the real, uncapped membership count - a folder whose real count exceeds the reachable ceiling" do
      allow(Danbooru.config.custom_configuration).to receive(:max_numbered_pages).and_return(2)
      3.times { |i| file_post!(days_ago: 3 - i) } # real count 3, ceiling = 2 pages * 1/page = 2

      set = PostSets::Favorites.new(user, "2", limit: 1, folder_scoped: true, folder: folder)
      posts = set.posts

      # Pagination metadata itself stays capped exactly as before - this is what keeps
      # numbered pagination from ever advertising a page beyond the reachable ceiling.
      expect(posts.total_count).to eq(2)
      expect(posts.total_pages).to eq(2)

      # But the real count is not lost - it's available for display purposes without a
      # second COUNT query, and capped? correctly flags that capping actually occurred.
      expect(posts.real_total_count).to eq(3)
      expect(posts.capped?).to be true
    end

    it "does not consider a folder capped when its real count fits within the reachable ceiling (real_total_count still set, but equal to total_count)" do
      file_post!(days_ago: 1)

      set = PostSets::Favorites.new(user, "1", limit: 40, folder_scoped: true, folder: folder)
      posts = set.posts

      expect(posts.real_total_count).to eq(posts.total_count)
      expect(posts.capped?).to be false
    end
  end

  describe "SQL executed" do
    # Both patterns match how Danbooru::Paginator::ActiveRecordExtension literally builds
    # its sequential-mode SQL (raw "#{table_name}.id < ?"/"#{table_name}.id desc" string
    # interpolation, unquoted) - see paginate_sequential_before/after. Their absence here
    # is the proof that folder_membership_posts's discarded `parsed.paginate_posts(...)`
    # call - kept only for its parsing/validation side effect - never actually executes
    # the id-ordered relation it builds, whether or not that relation would have been
    # sequential mode.
    def id_ordered_membership_queries(&block)
      queries = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        queries << payload[:sql] if payload[:sql]&.include?("favorite_folder_memberships")
      end
      block.call
      ActiveSupport::Notifications.unsubscribe(subscriber)
      queries.select { |sql| sql.match?(/favorite_folder_memberships\.id\s*[<>]/) || sql.match?(/order by favorite_folder_memberships\.id/i) }
    end

    it "issues no id-ordered/id-cursor query for an ordinary numbered folder page" do
      file_post!(days_ago: 1)
      set = PostSets::Favorites.new(user, "1", limit: 40, folder_scoped: true, folder: folder)

      bad_queries = id_ordered_membership_queries { set.posts }
      expect(bad_queries).to be_empty
    end

    it "issues no id-ordered/id-cursor query even for a rejected legacy cursor token, before PaginationError is raised" do
      file_post!(days_ago: 1)
      set = PostSets::Favorites.new(user, "b1", limit: 40, folder_scoped: true, folder: folder)

      bad_queries = id_ordered_membership_queries { expect { set.posts }.to raise_error(Danbooru::Paginator::PaginationError) }
      expect(bad_queries).to be_empty
    end
  end
end
