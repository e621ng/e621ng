# frozen_string_literal: true

class SavedSearch < ApplicationRecord
  QUERY_LENGTH_LIMIT = 500
  # count_only caps track_total_hits here; the badge never needs exact large numbers.
  BADGE_COUNT_CAP = 100
  # How long a badge entry outlives its freshness window (saved_search_badge_ttl), so the
  # header can keep showing the last known value while a refresh is pending.
  BADGE_RETENTION = 1.day
  # Everything query parsing can raise. User::PrivilegeError (set:/fav: the user can't view)
  # is an Exception, not a StandardError, so it has to be named explicitly.
  QUERY_ERRORS = [
    TagQuery::CountExceededError,
    TagQuery::InvalidTagError,
    TagQuery::DepthExceededError,
    ParseValue::InvalidDateError,
    User::PrivilegeError,
  ].freeze

  belongs_to :user

  before_validation :normalize_name
  before_validation :normalize_query, if: :query_changed?
  validates :query, presence: true, length: { maximum: QUERY_LENGTH_LIMIT }
  validates :query, uniqueness: { scope: :user_id, message: "is already saved" }, if: :query_changed?
  validates :name, length: { in: 3..100 }, allow_nil: true
  validates :name, format: { with: /\A[\w]+\z/, message: "must only contain numbers, lowercase letters, and underscores" }, allow_nil: true
  # No all-digit names: they would shadow search:<id> resolution.
  validates :name, format: { with: /\A\d*[a-z_][\w]*\z/, message: "must contain at least one lowercase letter or underscore" }, allow_nil: true
  validates :name, uniqueness: { scope: :user_id, message: "is already taken" }, allow_nil: true, if: :name_changed?
  validate :validate_query_parses, if: :query_changed?
  validate :validate_saved_search_limit, on: :create
  validate :validate_tracked_limit, if: :is_tracked_changed?

  before_save :reset_watermark, if: :is_tracked_changed?
  # Not after_commit: matches UserTotp, and commit callbacks never fire under transactional specs
  after_create :sync_user_flag, if: :is_tracked?
  after_update :sync_user_flag, if: :saved_change_to_is_tracked?
  after_destroy :sync_user_flag, if: :is_tracked?

  scope :tracked, -> { where(is_tracked: true) }

  # Resolves a `search:` metatag value to a saved search id. Scoped to the given
  # user: another user's id or name fails resolution (returns nil) rather than erroring.
  def self.name_or_id_to_id(str, user)
    return nil unless user&.is_logged_in?
    if str =~ /\A\d+\z/
      where(id: ParseValue.safe_id(str), user_id: user.id).pick(:id)
    else
      where(user_id: user.id, name: str.downcase.tr(" ", "_")).pick(:id)
    end
  end

  concerning :BadgeMethods do
    class_methods do
      # Safe mode depends on the site and request as well as the user, so each variant gets its
      # own entry. The defaults suit the request path; off-request callers must pass it.
      def badge_cache_key(user_id, safe_mode = CurrentUser.safe_mode?)
        safe_mode ? "ssb:#{user_id}:s" : "ssb:#{user_id}"
      end

      def badge_cache_keys(user_id)
        [false, true].map { |safe_mode| badge_cache_key(user_id, safe_mode) }
      end

      # Posts newer than the watermark that currently match the stored query. Never round-trips
      # through `search:` syntax; parses with the saved-search restrictions so a row that slipped
      # past validation fails closed instead of expanding wildcards.
      # Returns nil when the query can't be evaluated, so one bad search never takes down the rest.
      def new_post_count(saved_search, safe_mode: CurrentUser.safe_mode?)
        ElasticPostQueryBuilder.new(
          "#{saved_search.query} id:>#{saved_search.last_seen_post_id.to_i}",
          enable_safe_mode: safe_mode,
          # The reserved slot is consumed by the appended id:> term
          free_tags_count: 0,
          process_groups: true,
          allow_wildcard_tags: false,
          allow_saved_search_metatag: false,
        ).search.count_only(max_count: BADGE_COUNT_CAP)
      rescue *QUERY_ERRORS
        nil
      rescue OpenSearch::Transport::Transport::Error => e
        Rails.logger.warn("SavedSearch ##{saved_search.id} count failed: #{e.class}: #{e.message.truncate(200)}")
        nil
      end

      # Recomputes and caches the per-search new-post counts for all of the user's tracked
      # searches. Evaluated as the owning user: nothing is shared, so self-referential
      # metatags (fav:me) work and nothing leaks. A future shared per-query cache would
      # have to switch to anonymous evaluation.
      def refresh_badge_counts!(user, safe_mode: CurrentUser.safe_mode?)
        counts = {}
        CurrentUser.scoped(user) do
          user.saved_searches.tracked.each do |saved_search|
            counts[saved_search.id] = new_post_count(saved_search, safe_mode: safe_mode)
          end
        end
        write_badge_entry(badge_cache_key(user.id, safe_mode), counts)
        counts
      end

      # Cached entry ({ counts: {id => count}, at: epoch }) or nil when absent.
      # May be stale; see badge_entry_fresh?.
      def badge_entry(user, safe_mode: CurrentUser.safe_mode?)
        read_badge_entry(badge_cache_key(user.id, safe_mode))
      end

      def badge_entry_fresh?(entry)
        entry.present? && entry[:at] > Danbooru.config.saved_search_badge_ttl.ago.to_i
      end

      # { count: Integer or nil (nothing cached), fresh: Boolean }. Cache read only.
      def badge_summary(user, safe_mode: CurrentUser.safe_mode?)
        entry = badge_entry(user, safe_mode: safe_mode)
        { count: entry && entry[:counts].values.compact.sum, fresh: badge_entry_fresh?(entry) }
      end

      # Last known counts map ({id => count}), fresh or not; nil when absent.
      # A nil count means the search could not be evaluated.
      def badge_counts(user, safe_mode: CurrentUser.safe_mode?)
        badge_entry(user, safe_mode: safe_mode)&.fetch(:counts)
      end

      def read_badge_entry(key)
        entry = Cache.fetch(key)
        entry if entry.is_a?(Hash) && entry[:counts].is_a?(Hash)
      end

      def write_badge_entry(key, counts, at: Time.now.to_i)
        Cache.write(key, { counts: counts, at: at }, expires_in: BADGE_RETENTION)
      end

      def mark_all_seen!(user)
        watermark = Post.maximum(:id)
        tracked_ids = user.saved_searches.tracked.pluck(:id)
        user.saved_searches.tracked.update_all(last_seen_post_id: watermark)
        # Watermarks are shared across safe-mode variants
        badge_cache_keys(user.id).each { |key| write_badge_entry(key, tracked_ids.index_with { 0 }) }
      end
    end

    # Advances the watermark and zeroes this search's cached badge entries.
    # Returns the old watermark for the "only new posts" redirect.
    def mark_seen!
      return nil unless is_tracked?
      old_watermark = last_seen_post_id
      update_column(:last_seen_post_id, Post.maximum(:id))
      self.class.badge_cache_keys(user_id).each do |key|
        entry = self.class.read_badge_entry(key)
        next unless entry
        # Leaves an unevaluable (nil) entry alone
        entry[:counts][id] &&= 0
        # Keeps the original timestamp so visits don't postpone the next refresh
        self.class.write_badge_entry(key, entry[:counts], at: entry[:at])
      end
      old_watermark
    end
  end

  def normalize_name
    self.name = name.presence && name.downcase.tr(" ", "_")
  end

  def normalize_query
    normalized = query.to_s.unicode_normalize(:nfc).strip.gsub(/[[:space:]]+/, " ")
    # Full normalization (sort/alias/dedup) only for simple queries — the TagQuery
    # normalizers corrupt groups and quoted metatag values when reconstructing a string.
    if normalized.exclude?(':"') && !TagQuery.has_groups?(normalized)
      normalized = TagQuery.normalize(normalized)
    end
    self.query = normalized
  end

  def validate_query_parses
    TagQuery.new(
      query,
      # Reserves the slot the badge evaluation spends on its appended id:> term
      free_tags_count: 1,
      process_groups: true,
      error_on_depth_exceeded: true,
      allow_wildcard_tags: false,
      allow_saved_search_metatag: false,
    )
  rescue User::PrivilegeError
    errors.add(:query, "references a set or favorites you can't view")
  rescue *QUERY_ERRORS => e
    errors.add(:query, e.message)
  end

  def validate_saved_search_limit
    if user.saved_searches.count >= Danbooru.config.saved_search_limit
      errors.add(:base, "You can only have up to #{Danbooru.config.saved_search_limit} saved searches")
    end
  end

  def validate_tracked_limit
    if is_tracked? && user.saved_searches.tracked.where.not(id: id).count >= Danbooru.config.tracked_saved_search_limit
      errors.add(:base, "You can only track up to #{Danbooru.config.tracked_saved_search_limit} saved searches")
    end
  end

  def reset_watermark
    self.last_seen_post_id = is_tracked? ? Post.maximum(:id) : nil
  end

  # Atomic bit flip (cf. UserTotp.set_user_flag) so concurrent writes to other
  # bit_prefs flags can't be clobbered.
  def sync_user_flag
    tracked = SavedSearch.tracked.where(user_id: user_id).exists?
    mask = User.flag_value_for("has_tracked_saved_searches")
    operation = tracked ? "bit_prefs | #{mask}" : "bit_prefs & ~#{mask}"
    User.where(id: user_id).update_all("bit_prefs = #{operation}")
    self.class.badge_cache_keys(user_id).each { |key| Cache.delete(key) }
  end
end
