# frozen_string_literal: true

class StaffWiki < ApplicationRecord
  class RevertError < StandardError; end

  after_save :create_version
  after_save :create_references

  normalizes :body, with: ->(body) { body.gsub("\r\n", "\n") }

  validates :title, presence: true, length: { minimum: 1, maximum: 100 }
  validates :title, uniqueness: { case_sensitive: false }, on: :create
  validates :body, length: { maximum: Danbooru.config.wiki_page_max_size }
  validate :validate_claimant_id

  attr_accessor :related_type, :related_id

  belongs_to_creator
  belongs_to_updater
  belongs_to :claimant, class_name: "User", optional: true
  has_many :versions, -> { order("staff_wiki_versions.id ASC") }, class_name: "StaffWikiVersion", dependent: :destroy
  has_many :references, class_name: "StaffWikiRef", dependent: :destroy

  module ValidationMethods
    def validate_claimant_id
      return if claimant_id.blank?

      unless User.exists?(claimant_id)
        errors.add(:claimant_id, "must refer to an existing user")
      end
    end
  end

  module SearchMethods
    def titled(title)
      find_by(title: title)
    end

    def search(params)
      q = super

      q = q.where_ilike(:title, params[:title]) if params[:title].present?
      q = q.attribute_matches(:body, params[:body_matches])
      q = q.where_user(:creator_id, :creator, params)

      if params[:editor_id].present?
        q = q.where(id: StaffWikiVersion.where(updater_id: params[:editor_id]).select(:staff_wiki_id))
      end

      case params[:order]
      when "title"
        q.order("title")
      else
        q.apply_basic_order(params)
      end
    end
  end

  include ValidationMethods
  extend SearchMethods

  def revert_to(version)
    raise RevertError, "Version does not belong to this page." unless version.staff_wiki_id == id

    self.title = version.title
    self.body = version.body
  end

  def revert_to!(version)
    revert_to(version)
    save!
  end

  private

  def staff_wiki_changed?
    saved_change_to_title? || saved_change_to_body?
  end

  def create_version
    return unless staff_wiki_changed?

    versions.create(
      updater_id:      updater_id,
      updater_ip_addr: CurrentUser.ip_addr,

      title:           title,
      body:            body,
      claimant_id:     claimant_id,
    )
  end

  def create_references
    return unless related_type.present? && related_id.present?

    references.create(related_type: related_type.classify, related_id: related_id)
  end
end
