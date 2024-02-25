# frozen_string_literal: true

class PoolVersion < ApplicationRecord
  user_status_counter :pool_edit_count, foreign_key: :updater_id
  belongs_to :updater, :class_name => "User"
  before_validation :fill_version, on: :create
  before_validation :fill_changes, on: :create

  module SearchMethods
    def default_order
      order(updated_at: :desc)
    end

    def for_user(user_id)
      where("updater_id = ?", user_id)
    end

    def search(params)
      q = super

      q = q.where_user(:updater_id, :updater, params)

      if params[:pool_id].present?
        q = q.where(pool_id: params[:pool_id].split(",").map(&:to_i))
      end

      if params[:ip_addr].present?
        q = q.where("updater_ip_addr <<= ?", params[:ip_addr])
      end

      q.apply_basic_order(params)
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
                    category: pool.category
                })
  end

  def self.calculate_version(pool_id)
    1 + where("pool_id = ?", pool_id).maximum(:version).to_i
  end

  def fill_version
    self.version = PoolVersion.calculate_version(self.pool_id)
  end

  def fill_changes
    if previous
      self.added_post_ids = post_ids - previous.post_ids
      self.removed_post_ids = previous.post_ids - post_ids
    else
      self.added_post_ids = post_ids
      self.removed_post_ids = []
    end

    self.description_changed = previous.nil? ? true : description != previous.description
    self.name_changed = previous.nil? ? true : name != previous.name
  end

  def previous
    @previous ||= PoolVersion.where("pool_id = ? and version < ?", pool_id, version).order("version desc").first
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
