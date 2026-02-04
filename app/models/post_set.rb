# frozen_string_literal: true

class PostSet < ApplicationRecord
  array_attribute :post_ids, parse: %r{(?:https://(?:e621|e926)\.net/posts/)?(\d+)}i, cast: :to_i

  has_many :post_set_maintainers, dependent: :destroy do
    def in_cooldown(user)
      where(creator_id: user.id, status: "cooldown").where("created_at < ?", 24.hours.ago)
    end

    def active
      where(status: "approved")
    end

    def pending
      where(status: "pending")
    end

    def banned
      where(status: "banned")
    end
  end
  has_many :maintainers, class_name: "User", through: :post_set_maintainers, source: :user
  belongs_to_creator
  user_status_counter :set_count

  before_validation :normalize_shortname
  validates :name, length: { in: 3..100, message: "must be between three and one hundred characters long" }
  validates :name, :shortname, uniqueness: { case_sensitive: false, message: "is already taken" }, if: :if_names_changed?
  validates :shortname, length: { in: 3..50, message: "must be between three and fifty characters long" }
  validates :shortname, format: { with: /\A[\w]+\z/, message: "must only contain numbers, lowercase letters, and underscores" }
  validates :shortname, format: { with: /\A\d*[a-z_][\w]*\z/, message: "must contain at least one lowercase letter or underscore" }
  validates :description, length: { maximum: Danbooru.config.pool_descr_max_size }
  validate :validate_number_of_posts
  validate :can_make_public, if: :is_public_changed?
  validate :set_per_hour_limit, on: :create
  validate :can_create_new_set_limit, on: :create

  before_save :update_post_count
  after_update :send_maintainer_public_dmails
  before_destroy :send_maintainer_destroy_dmails

  # Only synchronize if post_ids were updated manually, not via the SQL helpers.
  after_save :synchronize, if: :synchronize_after_save?
  after_save :reset_manual_post_ids_write

  after_commit :enqueue_destroy_cleanup, on: :destroy

  # manual_post_ids_write: set to true when post_ids is changed via the attribute writer
  attr_accessor :manual_post_ids_write

  def self.name_to_id(name)
    if name =~ /\A\d+\z/
      ParseValue.safe_id(name)
    else
      PostSet.where("lower(shortname) = ?", name.downcase.tr(" ", "_")).pick(:id).to_i
    end
  end

  def self.visible(user = CurrentUser.user)
    return where("is_public = true") if user.nil?
    return all if user.is_moderator?
    where("is_public = true OR creator_id = ?", user.id)
  end

  def self.owned(user = CurrentUser.user)
    where("creator_id = ?", user.id)
  end

  def self.active_maintainer(user = CurrentUser.user)
    joins(:post_set_maintainers).where(post_set_maintainers: { status: "approved", user_id: user.id })
  end

  def if_names_changed?
    name_changed? || shortname_changed?
  end

  def saved_change_to_watched_attributes?
    saved_change_to_name? || saved_change_to_shortname? || saved_change_to_description? || saved_change_to_transfer_on_delete?
  end

  module ValidationMethods
    def normalize_shortname
      if shortname_changed?
        shortname.downcase!
      end
    end

    def send_maintainer_public_dmails
      if RateLimiter.check_limit("set.public.#{id}", 1, 24.hours)
        return
      end
      if is_public_changed? && !is_public # If set was made private
        RateLimiter.hit("set.public.#{id}", 24.hours)
        PostSetMaintainer.active.where(post_set_id: id).find_each do |maintainer|
          Dmail.create_automated(to_id: maintainer.user_id, title: "A set you maintain was made private",
                                 body: "The set \"#{name}\":#{post_set_path(self)} by \"#{creator.name}\":#{user_path(creator)} that you maintain was set to private. You will not be able to view, add posts, or remove posts from the set until the owner makes it public again.")
        end

        PostSetMaintainer.pending.where(post_set_id: id).delete
      elsif is_public_changed? && is_public # If set was made public
        RateLimiter.hit("set.public.#{id}", 24.hours)
        PostSetMaintainer.active.where(post_set_id: id).find_each do |maintainer|
          Dmail.create_automated(to_id: maintainer.user_id, title: "A private set you had maintained was made public again",
                                 body: "The set \"#{name}\":#{post_set_path(self)} by \"#{creator.name}\":#{user_path(creator)} that you previously maintained was made public again. You are now able to view the set and add/remove posts.")
        end
      end
    end

    def send_maintainer_destroy_dmails
      PostSetMaintainer.active.where(post_set_id: id).find_each do |maintainer|
        Dmail.create_automated(to_id: maintainer.user_id,
                               title: "A set you maintain was deleted",
                               body: "The set #{name} by \"#{creator.name}\":#{user_path(creator)} that you maintain was deleted.")
      end
    end

    def can_make_public
      if is_public && creator.younger_than(3.days) && !creator.is_janitor?
        errors.add(:base, "Can't make a set public until your account is at least three days old")
        false
      else
        true
      end
    end

    def can_create_new_set_limit
      if PostSet.where(creator_id: creator.id).count >= 75
        errors.add(:base, "You can only create 75 sets.")
        return false
      end
      true
    end

    def set_per_hour_limit
      if PostSet.where("created_at > ? AND creator_id = ?", 1.hour.ago, creator.id).count > 6 && !creator.is_janitor?
        errors.add(:base, "You have already created 6 sets in the last hour.")
        false
      else
        true
      end
    end

    def validate_number_of_posts
      post_ids_before = post_ids_before_last_save || post_ids_was
      added = post_ids - post_ids_before
      return if added.empty?
      max = max_posts
      if post_ids.size > max
        errors.add(:base, "Sets can only have up to #{ActiveSupport::NumberHelper.number_to_delimited(max)} posts each")
        false
      else
        true
      end
    end
  end

  module AccessMethods
    def can_view?(user)
      is_public || is_owner?(user) || user.is_moderator?
    end

    def can_edit_settings?(user)
      is_owner?(user) || user.is_admin?
    end

    def can_edit_posts?(user)
      can_edit_settings?(user) || (is_maintainer?(user) && is_public)
    end

    def is_maintainer?(user)
      return false if user.is_blocked?
      post_set_maintainers.where(user_id: user.id, status: "approved").count > 0
    end

    def is_invited?(user)
      post_set_maintainers.where(user_id: user.id, status: "pending").count > 0
    end

    def is_blocked?(user)
      post_set_maintainers.where(user_id: user.id, status: "blocked").count > 0
    end

    def is_owner?(user)
      return false if user.is_blocked?
      creator_id == user.id
    end

    def is_over_limit?
      post_count.to_i > max_posts + 100
    end
  end

  module WriteMethods
    # Track manual changes to post_ids to decide whether to run after_save synchronization.
    def post_ids=(value)
      self.manual_post_ids_write = true
      super
    end
    # ======================================== #
    # ========== Add posts to a set ========== #
    # ======================================== #

    # Add specified post IDs.
    # Delegates to SQL helper and performs synchronization for affected posts.
    def add(ids)
      ids = Array(ids)
      added = process_posts_add!(ids)
      if added.size <= 1
        sync_posts_for_delta(added_ids: added) if added.any?
      else
        PostSetPostsSyncJob.perform_later(id, added_ids: added)
      end
      added
    end

    # Add a single post to the set.
    def add!(post)
      return if post.nil? || post.id.nil?
      added = process_posts_add!([post.id])
      if added.empty?
        # Surface capacity error similarly to validation path
        if capacity <= 0 || is_over_limit?
          max = max_posts
          errors.add(:base, "Sets can only have up to #{ActiveSupport::NumberHelper.number_to_delimited(max)} posts each")
        end
        return
      end

      post.add_set!(self, true)
      post.save
    end

    # Add specified post IDs to the set using SQL functions.
    # Does not perform any synchronization; caller is responsible for that.
    def process_posts_add!(ids)
      ids = ids.map(&:to_i).uniq

      # Fast path for single id: split into smaller, faster queries
      if ids.length == 1
        pid = ids.first
        return [] unless Post.where(id: pid).exists?

        max = max_posts
        return [] if post_count >= max
        return [] if post_ids.include?(pid)

        conn = PostSet.connection
        conn.execute("SET LOCAL statement_timeout = '30s'") if post_count >= 1000

        update_sql = <<~SQL.squish
          UPDATE post_sets
          SET post_ids = array_append(post_ids, $1),
              post_count = post_count + 1,
              updated_at = $2
          WHERE id = $3
            AND post_count < $4
        SQL
        result = conn.raw_connection.exec_params(update_sql, [pid, Time.current.utc, id, max])

        return result.cmd_tuples > 0 ? [pid] : []
      end

      # Slower path for multiple ids: process the diff in the database
      valid_ids = Post.where(id: ids).pluck(:id)
      return [] if valid_ids.empty?

      current_ids = post_ids
      new_ids = valid_ids - current_ids
      return [] if new_ids.empty?

      max = max_posts.to_i
      return [] if post_count >= max

      available_capacity = max - post_count
      if new_ids.length > available_capacity
        new_ids = new_ids.first(available_capacity)
      end
      return [] if new_ids.empty?

      conn = PostSet.connection
      conn.execute("SET LOCAL statement_timeout = '30s'") if post_count >= 1000
      sql = <<~SQL.squish
        WITH input AS (
          SELECT id, ord
          FROM unnest($1::int[]) WITH ORDINALITY AS t(id, ord)
        ),
        curr AS (
          SELECT ps.id, ps.post_ids, COALESCE(array_length(ps.post_ids, 1), 0) AS cnt
          FROM post_sets ps
          WHERE ps.id = $2
          FOR UPDATE
        ),
        delta AS (
          SELECT i.id
          FROM input i, curr c
          WHERE NOT (c.post_ids @> ARRAY[i.id]::integer[])
          ORDER BY i.ord
          LIMIT GREATEST(0, $3 - (SELECT cnt FROM curr))
        ),
        new_array AS (
          SELECT c.id,
                 c.post_ids || COALESCE((SELECT array_agg(d.id) FROM delta d), '{}') AS arr
          FROM curr c
        ),
        upd AS (
          UPDATE post_sets ps
          SET post_ids = n.arr,
              post_count = COALESCE(array_length(n.arr, 1), 0),
              updated_at = $4
          FROM new_array n
          WHERE ps.id = n.id AND EXISTS (SELECT 1 FROM delta)
          RETURNING 1
        )
        SELECT d.id FROM delta d
      SQL

      pg_array_literal = "{#{new_ids.join(',')}}"
      result = conn.raw_connection.exec_params(sql, [pg_array_literal, id, max, Time.current.utc])
      result.column_values(0).map!(&:to_i)
    end

    # ======================================== #
    # ====== Remove posts from the set ======= #
    # ======================================== #

    # Remove specified post IDs.
    # Delegates to SQL helper and performs synchronization for affected posts.
    def remove(ids)
      ids = Array(ids)
      removed = process_posts_remove!(ids)
      if removed.size <= 1
        sync_posts_for_delta(removed_ids: removed) if removed.any?
      else
        PostSetPostsSyncJob.perform_later(id, removed_ids: removed)
      end
      removed
    end

    # Remove a single post from the set.
    def remove!(post)
      return if post.nil? || post.id.nil?
      removed = process_posts_remove!([post.id])
      return if removed.empty?

      post.remove_set!(self)
      post.save
    end

    # Remove specified post IDs from the set using SQL functions.
    # Does not perform any synchronization; caller is responsible for that.
    def process_posts_remove!(ids)
      ids = ids.map(&:to_i).uniq
      return [] if ids.empty?

      # Fast path for single id: one atomic UPDATE.
      if ids.length == 1
        pid = ids.first
        return [] unless post_ids.include?(pid)

        conn = PostSet.connection
        conn.execute("SET LOCAL statement_timeout = '30s'") if post_count >= 1000

        update_sql = <<~SQL.squish
          UPDATE post_sets
          SET post_ids = array_remove(post_ids, $1),
              post_count = post_count - 1,
              updated_at = $2
          WHERE id = $3
        SQL
        result = conn.raw_connection.exec_params(update_sql, [pid, Time.current.utc, id])

        return result.cmd_tuples > 0 ? [pid] : []
      end

      # Slower path: multiple IDs to process atomically and return the actual removed ids.
      current_ids = post_ids
      existing_ids = ids & current_ids
      return [] if existing_ids.empty?

      conn = PostSet.connection
      conn.execute("SET LOCAL statement_timeout = '30s'") if post_count >= 1000
      sql = <<~SQL.squish
        WITH input AS (
          SELECT id FROM unnest($1::int[]) AS t(id)
        ),
        curr AS (
          SELECT ps.id, ps.post_ids
          FROM post_sets ps
          WHERE ps.id = $2
          FOR UPDATE
        ),
        new_array AS (
          SELECT c.id,
                 COALESCE((
                   SELECT array_agg(val ORDER BY ord)
                   FROM unnest(c.post_ids) WITH ORDINALITY AS t(val, ord)
                   WHERE NOT (val = ANY (SELECT id FROM input))
                 ), '{}') AS arr
          FROM curr c
        ),
        upd AS (
          UPDATE post_sets ps
          SET post_ids = n.arr,
              post_count = COALESCE(array_length(n.arr, 1), 0),
              updated_at = $3
          FROM new_array n
          WHERE ps.id = n.id AND ps.post_ids IS DISTINCT FROM n.arr
          RETURNING 1
        )
        SELECT i.id FROM input i
      SQL

      pg_array_literal = "{#{existing_ids.join(',')}}"
      result = conn.raw_connection.exec_params(sql, [pg_array_literal, id, Time.current.utc])
      result.column_values(0).map!(&:to_i)
    end

    # ======================================== #
    # ========= Post Synchronization ========= #
    # ======================================== #

    # Synchronize Post side for a known delta to avoid computing large diffs.
    def sync_posts_for_delta(added_ids: [], removed_ids: [])
      Post.where(id: added_ids).find_each do |post|
        post.add_set!(self, true)
        post.save
      end

      Post.where(id: removed_ids).find_each do |post|
        post.remove_set!(self)
        post.save
      end
    end

    def synchronize
      post_ids_before = post_ids_before_last_save || post_ids_was
      added = post_ids - post_ids_before
      removed = post_ids_before - post_ids

      added_posts = Post.where(id: added)
      added_posts.find_each do |post|
        post.add_set!(self, true)
        post.save
      end

      removed_posts = Post.where(id: removed)
      removed_posts.find_each do |post|
        post.remove_set!(self)
        post.save
      end
    end

    def synchronize!
      synchronize
      save if will_save_change_to_post_ids?
    end

    private

    # Only run after_save synchronization if post_ids changed and it was changed via the attribute writer.
    # SQL helpers don't use the writer and won't set this flag.
    def synchronize_after_save?
      saved_change_to_post_ids? && manual_post_ids_write == true
    end

    def reset_manual_post_ids_write
      self.manual_post_ids_write = false
    end

    def enqueue_destroy_cleanup
      PostSetCleanupJob.perform_later(:set, id)
    end
  end

  module PostMethods
    # Returns the global max number of posts allowed in a set.
    def max_posts
      Danbooru.config.post_set_post_limit.to_i
    end

    # Remaining capacity available before hitting the limit.
    def capacity
      max_posts - post_count.to_i
    end

    def contains?(post_id)
      post_ids.include?(post_id)
    end

    def page_number(post_id)
      post_ids.find_index(post_id).to_i + 1
    end

    def first_post?(post_id)
      post_id == post_ids.first
    end

    def last_post?(post_id)
      post_id == post_ids.last
    end

    def previous_post_id(post_id)
      return nil if first_post?(post_id) || !contains?(post_id)

      n = post_ids.index(post_id) - 1
      post_ids[n]
    end

    def next_post_id(post_id)
      return nil if last_post?(post_id) || !contains?(post_id)

      n = post_ids.index(post_id) + 1
      post_ids[n]
    end

    def normalize_post_ids
      # Bypass the attribute writer to avoid marking this as a manual change.
      self[:post_ids] = post_ids.uniq
    end

    def update_post_count
      normalize_post_ids
      self.post_count = post_ids.size
    end
  end

  module SearchMethods
    def selected_first(current_set_id)
      return where("true") if current_set_id.blank?
      current_set_id = current_set_id.to_i
      reorder(Arel.sql("(case post_sets.id when #{current_set_id} then 0 else 1 end), post_sets.name"))
    end

    def where_has_post(post_id)
      where("post_ids @> ARRAY[?]::integer[]", post_id)
    end

    def where_has_maintainer(user_id)
      joins(:maintainers).where("(post_set_maintainers.user_id = ? AND post_set_maintainers.status = ?) OR creator_id = ?", user_id, "approved", user_id)
    end

    def search(params)
      q = super

      q = q.where_user(:creator_id, :creator, params)

      if params[:name].present?
        q = q.attribute_matches(:name, params[:name], convert_to_wildcard: true)
      end
      if params[:shortname].present?
        q = q.where_ilike(:shortname, params[:shortname])
      end
      if params[:is_public].present?
        q = q.attribute_matches(:is_public, params[:is_public])
      end

      case params[:order]
      when "name"
        q = q.order(:name, id: :desc)
      when "shortname"
        q = q.order(:shortname, id: :desc)
      when "postcount", "post_count"
        q = q.order(post_count: :desc, id: :desc)
      when "created_at"
        q = q.order(:id)
      when "update", "updated_at"
        q = q.order(updated_at: :desc)
      else
        q = q.order(id: :desc)
      end

      q
    end
  end

  extend SearchMethods
  include ValidationMethods
  include AccessMethods
  include WriteMethods
  include PostMethods
end
