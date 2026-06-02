# frozen_string_literal: true

class StaffWiki < ApplicationRecord
  class RevertError < StandardError; end

  before_validation :normalize_title
  after_save :create_version

  normalizes :body, with: ->(body) { body.gsub("\r\n", "\n") }

  validates :title, presence: true, uniqueness: { case_sensitive: false }, length: { minimum: 1, maximum: 100 }
  validates :body, length: { maximum: Danbooru.config.wiki_page_max_size }

  attr_accessor :edit_reason

  belongs_to_creator
  belongs_to_updater
  has_many :versions, -> { order("staff_wiki_versions.id ASC") }, class_name: "StaffWikiVersion", dependent: :destroy

  module SearchMethods
    def titled(title)
      find_by(title: StaffWiki.normalize_name(title))
    end

    def search(params)
      q = super

      q = q.where_ilike(:title, params[:title]) if params[:title].present?
      q = q.attribute_matches(:body, params[:body_matches])
      q = q.where_user(:creator_id, :creator, params)

      case params[:order]
      when "title"
        q.order("title")
      else
        q.apply_basic_order(params)
      end
    end
  end

  extend SearchMethods

  def self.normalize_name(name)
    name&.downcase&.tr(" ", "_")
  end

  def normalize_title
    self.title = StaffWiki.normalize_name(title) if title.present?
  end

  def pretty_title
    title&.tr("_", " ") || ""
  end

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
      reason:          edit_reason,
    )
  end
end
