# frozen_string_literal: true

class TagSubscription < ApplicationRecord
  belongs_to :user
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :user_id, message: "is already subscribed to" }
  validate :validate_subscription_limit, on: :create

  after_destroy :expire_badge_counts

  def self.tag_names_for(user)
    joins(:tag).where(user_id: user.id).order("tags.name").pluck("tags.name")
  end

  # Subscribes the user to the named tags, following aliases and skipping unknown tags,
  # existing subscriptions, and anything past the limit.
  # Returns { added: [TagSubscription], skipped: [{ name:, reason: }] }.
  def self.subscribe!(user, names)
    limit = Danbooru.config.tag_subscription_limit
    names = Array(names).map { |name| Tag.normalize_name(name) }.compact_blank.uniq
    # Bounds the lookups for one request; the excess is reported rather than dropped
    overflow = names.drop(limit * 2)
    names = names.first(limit * 2)
    resolved = TagAlias.to_aliased_with_originals(names)
    tag_ids = Tag.where(name: resolved.values).pluck(:name, :id).to_h
    existing = where(user_id: user.id).pluck(:tag_id).to_set
    room = limit - existing.size

    to_add = {}
    skipped = []
    resolved.each do |requested, name|
      tag_id = tag_ids[name]
      if tag_id.nil?
        skipped << { name: requested, reason: "does not exist" }
      elsif existing.include?(tag_id) || to_add.key?(tag_id)
        skipped << { name: requested, reason: "already subscribed" }
      elsif to_add.size >= room
        skipped << { name: requested, reason: "over the limit of #{limit}" }
      else
        to_add[tag_id] = name
      end
    end
    skipped.concat(overflow.map { |name| { name: name, reason: "too many tags in one request" } })
    return { added: [], skipped: skipped } if to_add.empty?

    # No enclosing transaction: an anchor left behind by a failed insert is harmless (it is
    # kept when empty anyway).
    SavedSearch.subscription_for!(user)
    now = Time.current
    # Concurrent requests can race past the limit check by a few rows; accepted.
    insert_all(to_add.keys.map { |tag_id| { user_id: user.id, tag_id: tag_id, created_at: now } }, unique_by: %i[user_id tag_id])
    expire_badge_counts(user.id)
    { added: where(user_id: user.id, tag_id: to_add.keys).includes(:tag).to_a, skipped: skipped }
  end

  # The anchor's cached count no longer matches its tag set.
  def self.expire_badge_counts(user_id)
    SavedSearch.badge_cache_keys(user_id).each { |key| Cache.delete(key) }
  end

  def expire_badge_counts
    self.class.expire_badge_counts(user_id)
  end

  def validate_subscription_limit
    if TagSubscription.where(user_id: user_id).count >= Danbooru.config.tag_subscription_limit
      errors.add(:base, "You can only subscribe to up to #{Danbooru.config.tag_subscription_limit} tags")
    end
  end
end
