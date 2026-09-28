# frozen_string_literal: true

module PostSets
  class Favorites < PostSets::Base
    attr_reader :page, :limit, :folder

    def initialize(user, page, limit:, post_count: nil, folder_scoped: false, folder: nil) # rubocop:disable Metrics/ParameterLists
      super()
      @user = user
      @page = page
      @limit = limit
      @post_count = post_count
      @folder_scoped = folder_scoped
      @folder = folder
    end

    def tag_string
      "fav:#{@user.name}"
    end

    def current_page
      [page.to_i, 1].max
    end

    def folder_scoped?
      @folder_scoped
    end

    # legacy_flat_posts (no folder awareness whatsoever) backs both "not folder-scoped at
    # all" (JSON, non-owner) and, deliberately, stays completely untouched by anything
    # below - only the owner-HTML branch varies by position in the folder tree:
    # root_unfiled_posts at the root (favorites not currently filed into any folder, true
    # folder semantics) and folder_membership_posts inside an actual folder.
    def posts
      return folder_membership_posts if folder_scoped? && @folder.present?
      return root_unfiled_posts if folder_scoped?
      legacy_flat_posts
    end

    # Direct child folders of the current folder (or root-level folders if @folder is
    # nil), sorted case-insensitively alphabetically with id as a stable tiebreaker.
    # Non-recursive: only ever queries a single parent_id level.
    def child_folders
      return [] unless folder_scoped?
      @child_folders ||= ::FavoriteFolder.where(user_id: @user.id, parent_id: @folder&.id).order(Arel.sql("lower(name) asc"), :id)
    end

    # The folder_id to navigate to if "Go Up" is clicked: nil means root. Returns the
    # sentinel :none when not inside any folder at all (i.e. already at root), since nil
    # is separately meaningful ("this folder's parent is root") and must be distinguished
    # from "there is no Go Up target to render".
    def go_up_target
      return :none if @folder.nil?
      @folder.parent_id
    end

    def empty_for_display?
      return posts.empty? unless folder_scoped?
      posts.empty? && child_folders.empty?
    end

    def has_explicit?
      !CurrentUser.safe_mode?
    end

    def hidden_posts
      @hidden_posts ||= posts.reject(&:visible?)
    end

    def login_blocked_posts
      @login_blocked_posts ||= posts.select(&:loginblocked?)
    end

    def safe_posts
      @safe_posts ||= posts.select { |p| p.safeblocked? && !p.deleteblocked? }
    end

    def api_posts
      result = posts
      fill_children(result)
      fill_tag_types(result)
      result
    end

    def tag_array
      []
    end

    def presenter
      ::PostSetPresenters::Post.new(self)
    end

    def is_random?
      false
    end

    private

    # No join, no anti-join, no folder predicate of any kind - backs every request that
    # isn't the owner's own folder-scoped HTML view (`/favorites.json`, any other user's
    # `/favorites`), which stay entirely unaware that folder membership exists.
    def legacy_flat_posts
      @post_count ||= ::Post.tag_match("fav:#{@user.name} status:any").count_only
      @posts ||= begin # rubocop:disable Naming/MemoizedInstanceVariableName -- shared memo backing the public `posts` method for both code paths
        favs = ::Favorite.for_user(@user.id)
                         .includes(post: :uploader)
                         .order(created_at: :desc)
                         .paginate_posts(page, total_count: @post_count, limit: @limit)
        new_opts = { pagination_mode: :numbered, records_per_page: favs.records_per_page, total_count: @post_count, current_page: current_page }
        ::Danbooru::Paginator::PaginatedArray.new(favs.map(&:post), new_opts)
      end
    end

    # True folder semantics: shows only favorites not currently filed into any folder, via
    # an anti-membership check against the sidecar table (keyed by favorite_id, served by
    # its own existing unique index) - no new column or index needed on either table.
    #
    # The query is bounded by this user's own favorite count (scans only this user's rows
    # via index_favorites_on_user_id_and_created_at, never the whole favorites table) and
    # runs once per owner-HTML root page load only - never for JSON, non-owner, or folder
    # pages. Postgres's chosen join strategy for the anti-check (hash vs. nested loop) is
    # data/statistics dependent and not fixed by this code; re-verify if scale/shape
    # changes materially rather than assuming either holds indefinitely.
    def root_unfiled_posts
      @posts ||= begin # rubocop:disable Naming/MemoizedInstanceVariableName -- shared memo backing the public `posts` method for both code paths
        scope = ::Favorite.for_user(@user.id)
                          .where("NOT EXISTS (SELECT 1 FROM favorite_folder_memberships WHERE favorite_folder_memberships.favorite_id = favorites.id)")
        count = @post_count ||= scope.count
        favs = scope.includes(post: :uploader)
                    .order(created_at: :desc)
                    .paginate_posts(page, total_count: count, limit: @limit)
        new_opts = { pagination_mode: :numbered, records_per_page: favs.records_per_page, total_count: count, current_page: current_page }
        ::Danbooru::Paginator::PaginatedArray.new(favs.map(&:post), new_opts)
      end
    end

    # Folder pages are numbered-pagination-only, deliberately - see folder_max_numbered_pages.
    # Paginates from the sidecar membership table only - never touches favorites for
    # sorting, counting, or paging. favorite_created_at (a denormalized copy captured at
    # filing time) preserves "newest original favorite first" ordering without a join.
    # Posts are then fetched in a separate batch lookup and reordered in Ruby, rather than
    # joining memberships to posts, so this query's shape/cost never depends on anything
    # about `favorites` or `posts` beyond the ids this small table already stored.
    def folder_membership_posts
      @posts ||= begin # rubocop:disable Naming/MemoizedInstanceVariableName -- shared memo backing the public `posts` method for both code paths
        scope = ::FavoriteFolderMembership.where(user_id: @user.id, folder_id: @folder.id)
        count = @post_count ||= scope.count

        # Reuse Danbooru::Paginator's own page/limit parsing and validation (the same
        # "Invalid page number" / "cannot go beyond page X" / "Invalid limit" errors every
        # other paginated listing raises) via the same extending(...) mechanism
        # ApplicationRecord#paginate_posts itself uses - but never execute the relation it
        # builds; only its parsed metadata (current_page, pagination_mode, records_per_page)
        # is read. Folder pages never honor "aXX"/"bXX" cursor-mode page params - see the
        # explicit mode check below - so no relation this call could build is ever used.
        parsed = scope.extending(::Danbooru::Paginator::ActiveRecordExtension)
        parsed.paginate_posts(page, total_count: count, limit: @limit)

        # Folder pages are numbered-only by design (see folder_max_numbered_pages below): a
        # cursor-mode token can only reach here via a hand-crafted URL, since
        # folder_max_numbered_pages keeps PaginatorComponent from ever generating one.
        # Rejecting it outright - rather than translating it - is the point: this table's
        # id reflects *filing* time, not favorite time (a favorite can be filed into a
        # folder long after, or before, other filings), so id order has no reliable
        # relationship to favorite_created_at order, and any translation back to a numbered
        # position would need a COUNT scaling with the token's depth in the folder - exactly
        # the unbounded-cost shortcut this design avoids. A stale/foreign token is invalid
        # input, not "page 1"; it fails loudly like any other bad pagination param.
        unless parsed.pagination_mode == :numbered
          raise ::Danbooru::Paginator::PaginationError, "Invalid page number."
        end

        records_per_page = parsed.records_per_page
        current_page = parsed.current_page
        offset = (current_page - 1) * records_per_page

        memberships = scope.order(favorite_created_at: :desc, favorite_id: :desc)
                           .offset(offset).limit(records_per_page)

        post_ids = memberships.map(&:post_id)
        posts_by_id = ::Post.includes(:uploader).where(id: post_ids).index_by(&:id)
        ordered_posts = post_ids.filter_map { |id| posts_by_id[id] }

        new_opts = {
          pagination_mode: :numbered, records_per_page: records_per_page, current_page: current_page,
          # Capped, not the raw scope.count - see capped_total_count - so
          # PaginatorComponent never advertises a page validate_numbered_page! would reject.
          total_count: capped_total_count(count, records_per_page),
          # The real, uncapped count, for display only (PaginationHelper#approximate_count).
          # Never affects pagination math - only total_count above does.
          real_total_count: count,
          # Inflated by one so PaginatorComponent's cursor-mode switch never fires for a
          # folder page - see folder_max_numbered_pages. Not the value shown to users.
          max_numbered_pages: folder_max_numbered_pages,
          # The true, un-inflated reachable page ceiling, for display only (see
          # PaginationHelper#approximate_count) - never read by pagination math itself.
          real_max_numbered_pages: Danbooru.config.max_numbered_pages,
        }
        ::Danbooru::Paginator::PaginatedArray.new(ordered_posts, new_opts)
      end
    end

    # Deliberately one past the real ceiling, purely to keep PaginatorComponent's
    # `current_page >= max_numbered_pages` cursor-mode switch from ever firing for a
    # folder page. Not the real ceiling itself - see real_max_numbered_pages above.
    def folder_max_numbered_pages
      Danbooru.config.max_numbered_pages + 1
    end

    # Caps total_count (and so total_pages/last_page/has_next?) at the real, un-inflated
    # ceiling, so a folder whose real content exceeds it never advertises a "Next" page
    # validate_numbered_page! would reject. Only affects pagination metadata, never which
    # posts a given page shows.
    def capped_total_count(count, records_per_page)
      return count unless records_per_page > 0
      [count, Danbooru.config.max_numbered_pages * records_per_page].min
    end
  end
end
