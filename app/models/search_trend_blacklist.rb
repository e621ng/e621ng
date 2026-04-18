# frozen_string_literal: true

class SearchTrendBlacklist < ApplicationRecord
  CACHE_KEY = "search_trend_blacklist"
  CACHE_TTL = 1.hour

  belongs_to_creator

  validates :tag, presence: true
  validates :tag, uniqueness: { case_sensitive: false, message: "already exists" }
  validate :tag_is_not_bare_wildcard

  after_create :invalidate_cache
  after_create do |rec|
    ModAction.log(:search_trend_blacklist_create, { tag: rec.tag, reason: rec.reason })
  end
  after_update :invalidate_cache
  after_update do |rec|
    ModAction.log(:search_trend_blacklist_update, { tag: rec.tag, reason: rec.reason })
  end
  after_destroy :invalidate_cache
  after_destroy do |rec|
    ModAction.log(:search_trend_blacklist_delete, { tag: rec.tag, reason: rec.reason })
  end

  # Returns the lowercased list of tag patterns from cache.
  def self.cached_patterns
    Cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
      pluck(:tag).map(&:downcase)
    end
  end

  # Returns true if the tag matches any blacklisted pattern (including globs).
  def self.blacklisted?(tag)
    t = tag.to_s.downcase.strip
    return false if t.blank?

    cached_patterns.any? { |pat| File.fnmatch(pat, t, File::FNM_CASEFOLD) }
  end

  # Delete all SearchTrend rows whose tag matches this entry's glob pattern.
  def purge!
    pattern = self.class.glob_to_sql_like(tag.downcase)
    deleted = SearchTrend.where("tag ILIKE ?", pattern).delete_all
    ModAction.log(:search_trend_blacklist_purge, { tag: tag, reason: reason, deleted_count: deleted })
    deleted
  end

  # Translate a glob pattern (* and ?) to a SQL LIKE pattern.
  # Escaping is done with blocks to avoid gsub replacement-string ambiguity.
  def self.glob_to_sql_like(pattern)
    pattern
      .gsub("\\") { "\\\\" }
      .gsub("%") { "\\%" }
      .gsub("_") { "\\_" }
      .gsub("*", "%")
      .gsub("?", "_")
  end

  def self.search(params)
    q = super

    q = q.includes(:creator)

    if params[:tag].present?
      q = q.where("tag ILIKE ?", params[:tag].to_escaped_for_sql_like)
    end

    if params[:reason].present?
      q = q.where("reason ILIKE ?", params[:reason].to_escaped_for_sql_like)
    end

    q.apply_basic_order(params)
  end

  private

  def invalidate_cache
    Cache.delete(CACHE_KEY)
  end

  def tag_is_not_bare_wildcard
    return if tag.blank?

    if tag.strip == "*"
      errors.add(:tag, "cannot be a bare wildcard (*) — it would blacklist all tags")
    end
  end
end
