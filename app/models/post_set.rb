# frozen_string_literal: true

class PostSet < ApplicationRecord
  array_attribute :post_ids, parse: %r{(?:https://(?:e621|e926)\.net/posts/)?(\d+)}i, cast: :to_i

  has_many :post_set_maintainers, dependent: :destroy do
    def in_cooldown(user)
      where(creator_id: user.id, status: 'cooldown').where('created_at < ?', 24.hours.ago)
    end
    def active
      where(status: 'approved')
    end
    def pending
      where(status: 'pending')
    end
    def banned
      where(status: 'banned')
    end
  end
  has_many :maintainers, class_name: "User", through: :post_set_maintainers, source: :user
  belongs_to_creator
  user_status_counter :set_count

  before_validation :normalize_shortname
  validates :name, length: { in: 3..100, message: "must be between three and one hundred characters long" }
  validates :name, :shortname, uniqueness: { case_sensitive: false, message: "is already taken" }, if: :if_names_changed?
  validates :shortname, length: { in: 3..50, message: 'must be between three and fifty characters long' }
  validates :shortname, format: { with: /\A[\w]+\z/, message: "must only contain numbers, lowercase letters, and underscores" }
  validates :shortname, format: { with: /\A\d*[a-z_][\w]*\z/, message: "must contain at least one lowercase letter or underscore" }
  validates :description, length: { maximum: Danbooru.config.pool_descr_max_size }
  validate :validate_number_of_posts
  validate :can_make_public, if: :is_public_changed?
  validate :set_per_hour_limit, on: :create
  validate :can_create_new_set_limit, on: :create

  after_update :send_maintainer_public_dmails
  before_destroy :send_maintainer_destroy_dmails
  before_save :update_post_count
  after_save :synchronize, if: :saved_change_to_post_ids?

  attr_accessor :skip_sync

  def self.name_to_id(name)
    if name =~ /\A\d+\z/
      name.to_i
    else
      PostSet.where("lower(shortname) = ?", name.downcase.tr(" ", "_")).pick(:id).to_i
    end
  end

  def self.visible(user = CurrentUser.user)
    return where('is_public = true') if user.nil?
    return all if user.is_moderator?
    where('is_public = true OR creator_id = ?', user.id)
  end

  def self.owned(user = CurrentUser.user)
    where('creator_id = ?', user.id)
  end

  def self.active_maintainer(user = CurrentUser.user)
    joins(:post_set_maintainers).where(post_set_maintainers: {status: 'approved', user_id: user.id})
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
        self.shortname.downcase!
      end
    end

    def send_maintainer_public_dmails
      if RateLimiter.check_limit("set.public.#{id}", 1, 24.hours)
        return
      end
      if is_public_changed? && !is_public # If set was made private
        RateLimiter.hit("set.public.#{id}", 24.hours)
        PostSetMaintainer.active.where(post_set_id: id).each do |maintainer|
          Dmail.create_automated(to_id: maintainer.user_id, title: "A set you maintain was made private",
                                 body: "The set \"#{name}\":#{post_set_path(self)} by \"#{creator.name}\":#{user_path(creator)} that you maintain was set to private. You will not be able to view, add posts, or remove posts from the set until the owner makes it public again.")
        end

        PostSetMaintainer.pending.where(post_set_id: id).delete
      elsif is_public_changed? && is_public # If set was made public
        RateLimiter.hit("set.public.#{id}", 24.hours)
        PostSetMaintainer.active.where(post_set_id: id).each do |maintainer|
          Dmail.create_automated(to_id: maintainer.user_id, titlet: "A private set you had maintained was made public again",
                                 body: "The set \"#{name}\":#{post_set_path(self)} by \"#{creaator.name}\":#{user_path(creator)} that you previously maintained was made public again. You are now able to view the set and add/remove posts.")
        end
      end
    end

    def send_maintainer_destroy_dmails
      PostSetMaintainer.active.where(post_set_id: id).each do |maintainer|
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
      if PostSet.where(creator_id: creator.id).count() >= 75
        errors.add(:base, "You can only create 75 sets.")
        return false
      end
      true
    end

    def set_per_hour_limit
      if PostSet.where("created_at > ? AND creator_id = ?", 1.hour.ago, creator.id).count() > 6 && !creator.is_janitor?
        errors.add(:base, "You have already created 6 sets in the last hour.")
        false
      else
        true
      end
    end

    def validate_number_of_posts
      post_ids_before = post_ids_before_last_save || post_ids_was
      added = post_ids - post_ids_before
      return unless added.size > 0
      max = Danbooru.config.set_post_limit(CurrentUser.user)
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
      post_set_maintainers.where(user_id: user.id, status: 'approved').count() > 0
    end

    def is_invited?(user)
      post_set_maintainers.where(user_id: user.id, status: 'pending').count() > 0
    end

    def is_blocked?(user)
      post_set_maintainers.where(user_id: user.id, status: 'blocked').count() > 0
    end

    def is_owner?(user)
      return false if user.is_blocked?
      creator_id == user.id
    end

    def is_over_limit?(user)
      post_ids.size > Danbooru.config.set_post_limit(user) + 100
    end
  end

  module PostMethods
    def contains?(post_id)
      post_ids.include?(post_id)
    end

    def page_number(post_id)
      post_ids.find_index(post_id).to_i + 1
    end

    def add(ids)
      real_ids = Post.select(:id).where(id: ids)
      real_ids.each do |post|
        next if contains?(post.id)
        self.post_ids = post_ids + [post.id]
      end
    end

    def add!(post)
      return if post.nil?
      return if post.id.nil?
      return if contains?(post.id)

      with_lock do
        reload
        self.skip_sync = true
        update(post_ids: post_ids + [post.id])
        raise(ActiveRecord::Rollback) unless valid?
        post.add_set!(self, true)
        post.save
      end
    end

    def remove(ids)
      self.post_ids = post_ids - ids
    end

    def remove!(post)
      return unless contains?(post.id)

      with_lock do
        reload
        self.skip_sync = true
        update(post_ids: post_ids - [post.id])
        raise(ActiveRecord::Rollback) unless valid?
        post.remove_set!(self)
        post.save
      end
    end

    def post_count
      post_ids.size
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

    def synchronize
      return if skip_sync == true
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

    def normalize_post_ids
      self.post_ids = post_ids.uniq
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
      where('post_ids @> ARRAY[?]::integer[]', post_id)
    end

    def where_has_maintainer(user_id)
      joins(:maintainers).where('(post_set_maintainers.user_id = ? AND post_set_maintainers.status = ?) OR creator_id = ?', user_id, 'approved', user_id)
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
      when 'name'
        q = q.order(:name, id: :desc)
      when 'shortname'
        q = q.order(:shortname, id: :desc)
      when 'postcount', 'post_count'
        q = q.order(post_count: :desc, id: :desc)
      when 'created_at'
        q = q.order(:id)
      when 'update', 'updated_at'
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
  include PostMethods
end
