# frozen_string_literal: true

class SavedSearch < ApplicationRecord
  QUERY_LENGTH_LIMIT = 500
  # count_only caps track_total_hits here; the badge never needs exact large numbers.
  BADGE_COUNT_CAP = 100
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
      def badge_cache_key(user_id)
        "ssb:#{user_id}"
      end

      # Posts newer than the watermark that currently match the stored query. Never round-trips
      # through `search:` syntax; parses with the saved-search restrictions so a row that slipped
      # past validation fails closed instead of expanding wildcards.
      # Returns nil when the query can't be evaluated, so one bad search never takes down the rest.
      def new_post_count(saved_search)
        ElasticPostQueryBuilder.new(
          "#{saved_search.query} id:>#{saved_search.last_seen_post_id.to_i}",
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
      def refresh_badge_counts!(user)
        counts = {}
        CurrentUser.scoped(user) do
          user.saved_searches.tracked.each do |saved_search|
            counts[saved_search.id] = new_post_count(saved_search)
          end
        end
        Cache.write(badge_cache_key(user.id), counts, expires_in: Danbooru.config.saved_search_badge_ttl)
        counts
      end

      # Cached counts map ({id => count}) or nil when stale/absent.
      # A nil count means the search could not be evaluated.
      def badge_counts(user)
        Cache.fetch(badge_cache_key(user.id))
      end

      def mark_all_seen!(user)
        watermark = Post.maximum(:id)
        tracked_ids = user.saved_searches.tracked.pluck(:id)
        user.saved_searches.tracked.update_all(last_seen_post_id: watermark)
        Cache.write(badge_cache_key(user.id), tracked_ids.index_with { 0 }, expires_in: Danbooru.config.saved_search_badge_ttl)
      end
    end

    # Advances the watermark and zeroes this search's cached badge entry.
    # Returns the old watermark for the "only new posts" redirect.
    def mark_seen!
      return nil unless is_tracked?
      old_watermark = last_seen_post_id
      update_column(:last_seen_post_id, Post.maximum(:id))
      counts = Cache.fetch(self.class.badge_cache_key(user_id))
      if counts.is_a?(Hash)
        # Leaves an unevaluable (nil) entry alone
        counts[id] &&= 0
        Cache.write(self.class.badge_cache_key(user_id), counts, expires_in: Danbooru.config.saved_search_badge_ttl)
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
    Cache.delete(self.class.badge_cache_key(user_id))
  end
end
