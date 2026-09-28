# frozen_string_literal: true

module PostSets
  class Favorites < PostSets::Base
    attr_reader :page, :limit

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

    # The base Favorites query, byte-identical to how it worked before folders existed:
    # no join, no anti-join, no NOT EXISTS, no folder predicate of any kind. This backs
    # every request that isn't the owner's own folder-scoped HTML view - `/favorites.json`
    # and any other user's `/favorites` (HTML or JSON) - which stay entirely unaware that
    # folder membership exists as a concept. The owner's own HTML `/favorites` is NOT
    # universally flat: see `posts` above - it's folder-scoped (root_unfiled_posts /
    # folder_membership_posts) precisely because it's the owner viewing their own folders.
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

    # The owner-HTML root view: true folder semantics, so this shows only favorites not
    # currently filed into any folder - never a raw favorite_folder_id column/index on
    # favorites (there is none), just an anti-membership check against the sidecar table,
    # keyed by favorite_id and served entirely by that table's own existing unique index
    # (index_favorite_folder_memberships_on_favorite_id) - no new column or index on
    # favorites, and no new index on favorite_folder_memberships either.
    #
    # Plan choice for this NOT EXISTS shape is data/statistics dependent, not fixed: at
    # smaller sidecar sizes Postgres may choose a Hash Anti Join that scans
    # favorite_folder_memberships in full to build its hash table; at larger sidecar sizes
    # it has been observed to switch to a Nested Loop Anti Join using
    # favorite_folder_memberships' own unique favorite_id index instead. Don't assume
    # either strategy holds at a size/shape not yet measured.
    #
    # Strongest evidence so far is Phase 5/5.5 (see PR notes), tested up to 50,000,000
    # favorites / ~20,000,000 memberships: a Nested Loop Anti Join page-1 lookup ran
    # ~16ms, and a full anti-join COUNT over an 80,000-row probe set ran ~110ms - both
    # against favorite_ids deliberately scattered across the full id range (not a
    # synthetic user's own tightly-clustered ids), which Phase 5.5 showed can make
    # contiguous/local synthetic data look roughly 1.3-2.1x more optimistic than a real,
    # dispersed access pattern depending on the operation. These numbers are all
    # comfortably acceptable for this page, but should not be read as a universal
    # sub-millisecond guarantee - measure again if the access pattern or scale changes
    # materially. Either way, the query as a whole is still bounded by this user's own
    # favorite count (it only ever scans this user's rows via
    # index_favorites_on_user_id_and_created_at, never the whole favorites table), and is
    # paid only once per owner-HTML root page load (never for JSON, non-owner, or folder
    # pages).
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
          # Capped, not the raw scope.count - see capped_total_count. This is what keeps
          # PaginatorComponent's own last_page/has_next? (computed from total_pages, which
          # derives from total_count) from ever advertising a page beyond what
          # validate_numbered_page! actually allows.
          total_count: capped_total_count(count, records_per_page),
          # The real, uncapped membership count - already computed above via `count`, no
          # second COUNT query. Lets PaginationHelper#approximate_count show a true "over
          # N results" once a folder outgrows the numbered-page ceiling, instead of
          # reading the capped total_count above and mistaking it for the real, exact
          # total. Never affects pagination math itself - only total_count (above) does.
          real_total_count: count,
          # Kept strictly above Danbooru.config.max_numbered_pages (the real, unmodified
          # validation ceiling parse_page/validate_numbered_page! enforce above) so
          # PaginatorComponent's own `current_page >= max_numbered_pages` switch - shared,
          # global, deliberately untouched - never fires for this PostSet: it always renders
          # plain "?page=N" links, never "aXX"/"bXX" cursor links, for any folder page a
          # numbered request can actually reach. This is a per-instance PaginatedArray
          # option already designed for this purpose; no shared paginator code changes.
          max_numbered_pages: folder_max_numbered_pages,
        }
        ::Danbooru::Paginator::PaginatedArray.new(ordered_posts, new_opts)
      end
    end

    # One page past Danbooru.config.max_numbered_pages (the real, global, unmodified
    # validation ceiling that parse_page/validate_numbered_page! enforce above). Computed
    # per-call, not memoized/frozen at load time, so it stays correct if a spec ever swaps
    # Danbooru.config. Only ever used as a PaginatedArray#max_numbered_pages override - it
    # does not raise the true, global page-count ceiling itself.
    def folder_max_numbered_pages
      Danbooru.config.max_numbered_pages + 1
    end

    # PaginatorComponent computes last_page/has_next? purely from
    # [total_pages, max_numbered_pages].min, and total_pages derives from total_count. Left
    # uncapped, a folder whose real content exceeds the real ceiling would report a
    # total_pages one past it (since max_numbered_pages here is deliberately inflated by 1
    # - see folder_max_numbered_pages) - advertising a "Next" link to a page number
    # validate_numbered_page! then rejects. Capping total_count itself (not
    # max_numbered_pages, which still needs its +1 to suppress cursor-mode rendering) keeps
    # total_pages, and so last_page/has_next?/the numbered page-number list, from ever
    # exceeding the real, reachable ceiling. The actual per-page query above is untouched -
    # this only affects pagination metadata, never which posts a given page shows.
    def capped_total_count(count, records_per_page)
      return count unless records_per_page > 0
      [count, Danbooru.config.max_numbered_pages * records_per_page].min
    end
  end
end
