class Pool < ApplicationRecord
  class RevertError < Exception;
  end

  array_attribute :post_ids, parse: /\d+/, cast: :to_i
  belongs_to_creator

  validates :name, uniqueness: { case_sensitive: false, if: :name_changed? }
  validates :name, length: { minimum: 1, maximum: 250 }
  validates :description, length: { maximum: 10_000 }
  validate :user_not_create_limited, on: :create
  validate :user_not_limited, on: :update, if: :limited_attribute_changed?
  validate :user_not_posts_limited, on: :update, if: :post_ids_changed?
  validate :validate_name, if: :name_changed?
  validates :category, inclusion: { :in => %w(series collection) }
  validate :updater_can_change_category
  validate :updater_can_remove_posts
  validate :updater_can_edit_deleted
  validate :validate_number_of_posts
  before_validation :normalize_post_ids
  before_validation :normalize_name
  after_save :create_version
  after_save :synchronize, if: :saved_change_to_post_ids?
  after_create :synchronize!
  before_destroy :remove_all_posts

  attr_accessor :skip_sync

  def limited_attribute_changed?
    name_changed? || description_changed? || category_changed? || is_active_changed?
  end

  module SearchMethods
    def for_user(id)
      where("pools.creator_id = ?", id)
    end

    def deleted
      where("pools.is_deleted = true")
    end

    def undeleted
      where("pools.is_deleted = false")
    end

    def series
      where("pools.category = ?", "series")
    end

    def collection
      where("pools.category = ?", "collection")
    end

    def series_first
      order(Arel.sql("(case pools.category when 'series' then 0 else 1 end), pools.name"))
    end

    def selected_first(current_pool_id)
      return where("true") if current_pool_id.blank?
      current_pool_id = current_pool_id.to_i
      reorder(Arel.sql("(case pools.id when #{current_pool_id} then 0 else 1 end), pools.name"))
    end

    def name_matches(name)
      name = normalize_name_for_search(name)
      name = "*#{name}*" unless name =~ /\*/
      where("lower(pools.name) like ? escape E'\\\\'", name.to_escaped_for_sql_like)
    end

    def default_order
      order(updated_at: :desc)
    end

    def search(params)
      q = super

      if params[:name_matches].present?
        q = q.name_matches(params[:name_matches])
      end

      q = q.attribute_matches(:description, params[:description_matches])

      if params[:creator_name].present?
        q = q.where("pools.creator_id = (select _.id from users _ where lower(_.name) = ?)", params[:creator_name].tr(" ", "_").mb_chars.downcase)
      end

      if params[:creator_id].present?
        q = q.where(creator_id: params[:creator_id].split(",").map(&:to_i))
      end

      if params[:category] == "series"
        q = q.series
      elsif params[:category] == "collection"
        q = q.collection
      end

      q = q.attribute_matches(:is_active, params[:is_active])
      q = q.attribute_matches(:is_deleted, params[:is_deleted])

      params[:order] ||= params.delete(:sort)
      case params[:order]
      when "name"
        q = q.order("pools.name")
      when "created_at"
        q = q.order("pools.created_at desc")
      when "post_count"
        q = q.order(Arel.sql("cardinality(post_ids) desc")).default_order
      else
        q = q.apply_default_order(params)
      end

      q
    end
  end

  extend SearchMethods

  def user_not_create_limited
    allowed = creator.can_pool_with_reason
    if allowed != true
      errors.add(:creator, User.throttle_reason(allowed))
      return false
    end
    true
  end

  def user_not_limited
    allowed = CurrentUser.can_pool_edit_with_reason
    if allowed != true
      errors.add(:updater, User.throttle_reason(allowed))
      return false
    end
    true
  end

  def user_not_posts_limited
    allowed = CurrentUser.can_pool_post_edit_with_reason
    if allowed != true
      errors.add(:updater, User.throttle_reason(allowed) + ": updating unique pools posts")
      return false
    end
    true
  end

  def self.name_to_id(name)
    if name =~ /\A\d+\z/
      name.to_i
    else
      select_value_sql("SELECT id FROM pools WHERE lower(name) = ?", name.downcase.tr(" ", "_")).to_i
    end
  end

  def self.normalize_name(name)
    name.gsub(/[_[:space:]]+/, "_").gsub(/\A_|_\z/, "")
  end

  def self.normalize_name_for_search(name)
    normalize_name(name).mb_chars.downcase
  end

  def self.find_by_name(name)
    if name =~ /\A\d+\z/
      where("pools.id = ?", name.to_i).first
    elsif name
      where("lower(pools.name) = ?", normalize_name_for_search(name)).first
    else
      nil
    end
  end

  def versions
    PoolArchive.where("pool_id = ?", id).order("id asc")
  end

  def is_series?
    category == "series"
  end

  def is_collection?
    category == "collection"
  end

  def normalize_name
    self.name = Pool.normalize_name(name)
  end

  def pretty_name
    name.tr("_", " ")
  end

  def pretty_category
    category.titleize
  end

  def normalize_post_ids
    self.post_ids = post_ids.uniq if is_collection?
  end

  def revert_to!(version)
    if id != version.pool_id
      raise RevertError.new("You cannot revert to a previous version of another pool.")
    end

    self.post_ids = version.post_ids
    self.name = version.name
    self.description = version.description
    save
  end

  def contains?(post_id)
    post_ids.include?(post_id)
  end

  def page_number(post_id)
    post_ids.find_index(post_id).to_i + 1
  end

  def deletable_by?(user)
    user.is_moderator?
  end

  def updater_can_edit_deleted
    if is_deleted? && !deletable_by?(CurrentUser.user)
      errors[:base] << "You cannot update pools that are deleted"
    end
  end

  def create_mod_action_for_delete
    ModAction.log(:pool_delete, {pool_id: id, pool_name: name, user_id: creator_id})
  end

  def create_mod_action_for_undelete
    ModAction.log(:pool_undelete, {pool_id: id, pool_name: name, user_id: creator_id})
  end

  def validate_number_of_posts
    post_ids_before = post_ids_before_last_save || post_ids_was
    added = post_ids - post_ids_before
    return unless added.size > 0
    if post_ids.size > 1_000
      errors.add(:base, "Pools can have up to 1,000 posts each")
      false
    else
      true
    end
  end

  def add!(post)
    return if post.nil?
    return if post.id.nil?
    return if contains?(post.id)
    return if is_deleted?

    with_lock do
      reload
      self.skip_sync = true
      update(post_ids: post_ids + [post.id])
      post.add_pool!(self, true)
      post.save
    end
  end

  def add(id)
    return if id.nil?
    return if contains?(id)
    return if is_deleted?

    self.post_ids << id
  end

  def remove!(post)
    return unless contains?(post.id)
    return unless CurrentUser.user.can_remove_from_pools?

    with_lock do
      reload
      self.skip_sync = true
      update(post_ids: post_ids - [post.id])
      post.remove_pool!(self)
      post.save
    end
  end

  def posts(options = {})
    offset = options[:offset] || 0
    limit = options[:limit] || Danbooru.config.posts_per_page
    slice = post_ids.slice(offset, limit)
    if slice && slice.any?
      # This hack is here to work around posts that are not found but present in the pool id list.
      # Previously there was an N+1 post lookup loop.
      posts = Hash[Post.where(id: slice).map {|p| [p.id, p]}]
      slice.map {|id| posts[id]}.compact
    else
      []
    end
  end

  def synchronize
    return if skip_sync == true
    post_ids_before = post_ids_before_last_save || post_ids_was
    added = post_ids - post_ids_before
    removed = post_ids_before - post_ids

    Post.where(id: added).find_each do |post|
      post.add_pool!(self, true)
      post.save
    end

    Post.where(id: removed).find_each do |post|
      post.remove_pool!(self)
      post.save
    end
  end

  def synchronize!
    synchronize
    save if will_save_change_to_post_ids?
  end

  def remove_all_posts
    with_lock do
      transaction do
        Post.where(id: post_ids).find_each do |post|
          post.remove_pool!(self)
          post.save
        end
      end
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

  # XXX finds wrong post when the pool contains multiple copies of the same post (#2042).
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

  def cover_post_id
    post_ids.first
  end

  def create_version(updater: CurrentUser.user, updater_ip_addr: CurrentUser.ip_addr)
    PoolArchive.queue(self, updater, updater_ip_addr)
  end

  def last_page
    (post_count / CurrentUser.user.per_page.to_f).ceil
  end

  def method_attributes
    super + [:creator_name, :post_count]
  end

  def category_changeable_by?(user)
    user.is_janitor? || (user.is_member? && post_count <= Danbooru.config.pool_category_change_limit)
  end

  def updater_can_change_category
    if category_changed? && !category_changeable_by?(CurrentUser.user)
      errors[:base] << "You cannot change the category of pools with greater than #{Danbooru.config.pool_category_change_limit} posts"
    end
  end

  def validate_name
    case name
    when /\A(any|none|series|collection)\z/i
      errors[:name] << "cannot be any of the following names: any, none, series, collection"
    when /\*/
      errors[:name] << "cannot contain asterisks"
    when ""
      errors[:name] << "cannot be blank"
    when /\A[0-9]+\z/
      errors[:name] << "cannot contain only digits"
    end
  end

  def updater_can_remove_posts
    removed = post_ids_was - post_ids
    if removed.any? && !CurrentUser.user.can_remove_from_pools?
      errors[:base] << "You cannot removes posts from pools within the first week of sign up"
    end
  end
end
