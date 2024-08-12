# frozen_string_literal: true

class AvoidPosting < ApplicationRecord
  belongs_to_creator
  belongs_to_updater
  belongs_to :artist
  has_many :versions, -> { order("avoid_posting_versions.id ASC") }, class_name: "AvoidPostingVersion", dependent: :destroy
  validates :artist_id, uniqueness: { message: "already has an avoid posting entry" }
  after_create :log_create
  after_create :create_version
  after_update :log_update, if: :saved_change_to_watched_attributes?
  after_update :create_version, if: :saved_change_to_watched_attributes?
  after_destroy :log_destroy
  validates_associated :artist
  accepts_nested_attributes_for :artist
  after_commit :invalidate_cache

  scope :active, -> { where(is_active: true) }
  scope :deleted, -> { where(is_active: false) }

  module LogMethods
    def log_create
      ModAction.log(:avoid_posting_create, { id: id, artist_name: artist_name })
    end

    def saved_change_to_watched_attributes?
      saved_change_to_is_active? || saved_change_to_details? || saved_change_to_staff_notes?
    end

    def log_update
      entry = { id: id, artist_name: artist_name }
      if saved_change_to_is_active?
        action = is_active? ? :avoid_posting_undelete : :avoid_posting_delete
        ModAction.log(action, entry)
        # only log delete/undelete if only is_active changed (checking for 2 because of updated_at)
        return if previous_changes.length == 2
      end
      entry = entry.merge({ details: details, old_details: details_before_last_save }) if saved_change_to_details?
      entry = entry.merge({ staff_notes: staff_notes, old_staff_notes: staff_notes_before_last_save }) if saved_change_to_staff_notes?

      ModAction.log(:avoid_posting_update, entry)
    end

    def log_destroy
      ModAction.log(:avoid_posting_destroy, { id: id, artist_name: artist_name })
    end
  end

  def create_version
    AvoidPostingVersion.create({
      avoid_posting: self,
      details: details,
      staff_notes: staff_notes,
      is_active: is_active,
    })
  end

  def status
    if is_active?
      "Active"
    else
      "Deleted"
    end
  end

  module ArtistMethods
    delegate :group_name, :other_names, :other_names_string, :linked_user_id, :linked_user, :any_name_matches, to: :artist
    delegate :name, to: :artist, prefix: true, allow_nil: true
  end

  module ApiMethods
    def hidden_attributes
      attr = super
      attr += %i[staff_notes] unless CurrentUser.is_staff?
      attr
    end
  end

  module SearchMethods
    def artist_search(params)
      Artist.search(params.slice(:any_name_matches, :any_other_name_matches).merge({ id: params[:artist_id], name: params[:artist_name] }))
    end

    def search(params)
      q = super
      artist_keys = %i[artist_id artist_name any_name_matches any_other_name_matches]
      q = q.joins(:artist).merge(artist_search(params)) if artist_keys.any? { |key| params.key?(key) }

      if params[:is_active].present?
        q = q.active if params[:is_active].to_s.truthy?
        q = q.deleted if params[:is_active].to_s.falsy?
      else
        q = q.active
      end

      q = q.attribute_matches(:details, params[:details])
      q = q.attribute_matches(:staff_notes, params[:staff_notes])
      q = q.where_user(:creator_id, :creator, params)
      q = q.where("creator_ip_addr <<= ?", params[:ip_addr]) if params[:ip_addr].present?
      case params[:order]
      when "artist_name", "artist_name_asc"
        q = q.joins(:artist).order("artists.name ASC")
      when "artist_name_desc"
        q = q.joins(:artist).order("artists.name DESC")
      when "created_at"
        q = q.order("created_at DESC")
      when "updated_at"
        q = q.order("updated_at DESC")
      else
        q = q.apply_basic_order(params)
      end
      q
    end
  end

  def header
    first = artist_name[0]
    if first =~ /\d/
      "#"
    elsif first =~ /[a-z]/
      first.upcase
    else
      "?"
    end
  end

  def all_names
    return artist_name.tr("_", " ") if other_names.blank?
    "#{artist_name} / #{other_names.join(' / ')}".tr("_", " ")
  end

  def pretty_details
    return details if details.present?
    return "Only the artist is allowed to post." if linked_user_id.present?
    ""
  end

  def invalidate_cache
    Cache.delete("avoid_posting_list")
  end

  include LogMethods
  include ApiMethods
  include ArtistMethods
  extend SearchMethods
end
