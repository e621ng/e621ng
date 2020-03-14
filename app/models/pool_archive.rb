class PoolArchive < ApplicationRecord
  user_status_counter :pool_edit_count, foreign_key: :updater_id
  belongs_to :updater, :class_name => "User"
  before_validation :fill_version, on: :create
  before_validation :fill_changes, on: :create

  #establish_connection (ENV["ARCHIVE_DATABASE_URL"] || "archive_#{Rails.env}".to_sym) if enabled?
  self.table_name = "pool_versions"

  module SearchMethods
    def default_order
      order(updated_at: :desc)
    end

    def for_user(user_id)
      where("updater_id = ?", user_id)
    end

    def search(params)
      q = super

      if params[:updater_id].present?
        q = q.where(updater_id: params[:updater_id].split(",").map(&:to_i))
      end

      if params[:updater_name].present?
        q = q.where("updater_id = ?", User.name_to_id(params[:updater_name]))
      end

      if params[:pool_id].present?
        q = q.where(pool_id: params[:pool_id].split(",").map(&:to_i))
      end

      q.apply_default_order(params)
    end
  end

  extend SearchMethods

  def self.queue(pool, updater, updater_ip_addr)
    self.create({
                    pool_id: pool.id,
                    post_ids: pool.post_ids,
                    updater_id: updater.id,
                    updater_ip_addr: updater_ip_addr,
                    description: pool.description,
                    name: pool.name,
                    is_active: pool.is_active?,
                    is_deleted: pool.is_deleted?,
                    category: pool.category
                })
  end

  def self.calculate_version(pool_id)
    1 + where("pool_id = ?", pool_id).maximum(:version).to_i
  end

  def fill_version
    self.version = PoolArchive.calculate_version(self.pool_id)
  end

  def fill_changes
      prev = previous

      if prev
        self.added_post_ids = post_ids - prev.post_ids
        self.removed_post_ids = prev.post_ids - post_ids
      else
        self.added_post_ids = post_ids
        self.removed_post_ids = []
      end

      self.description_changed = prev.nil? || description != prev.try(:description)
      self.name_changed = prev.nil? || name != prev.try(:name)
  end

  def build_diff(other = nil)
    diff = {}
    prev = previous

    if prev.nil?
      diff[:added_post_ids] = added_post_ids
      diff[:removed_post_ids] = removed_post_ids
      diff[:added_desc] = description
    else
      diff[:added_post_ids] = added_post_ids
      diff[:removed_post_ids] = removed_post_ids
      diff[:added_desc] = description
      diff[:removed_desc] = prev.description
    end

    diff
  end

  def previous
    PoolArchive.where("pool_id = ? and version < ?", pool_id, version).order("version desc").first
  end

  def pool
    Pool.find(pool_id)
  end

  def updater
    User.find(updater_id)
  end

  def updater_name
    User.id_to_name(updater_id)
  end

  def pretty_name
    name&.tr("_", " ") || '(Unknown Name)'
  end
end
