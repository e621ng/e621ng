# frozen_string_literal: true

class PostFlagReason < ApplicationRecord
  belongs_to :parent, class_name: "PostFlagReason", optional: true
  has_many :children, class_name: "PostFlagReason", foreign_key: "parent_id", dependent: :nullify

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :reason, presence: true
  validates :category, presence: true, inclusion: { in: %w[flag report none] }
  validates :index, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  after_destroy :invalidate_cache
  after_save :invalidate_cache
  # TODO: Log ModAction for changes to flag reasons, similar to report reasons

  scope :ordered, -> { order(index: :asc, id: :asc) }
  scope :structured, -> { where(parent_id: nil).includes(:children) }

  scope :for_flags, -> { where(category: "flag") }
  scope :for_reports, -> { where(category: "report") }
  scope :for_none, -> { where(category: "none") }

  # Cached list of reasons for use in radio buttons
  # Structured to include sub-reasons as children
  def self.for_radio
    Rails.cache.fetch("post_flag_reasons:for_radio") do
      structured.ordered.to_a
    end
  end

  # Cached check for whether a reason name is valid, optionally within a specific category
  def self.is_valid_reason?(reason_name, category = :any)
    return false if reason_name.blank?

    lookup_map = Rails.cache.fetch("post_flag_reasons:for_name_validation") { pluck(:name, :category).to_h }
    reason_category = lookup_map[reason_name.to_s]
    return false if reason_category.nil?

    category == :any || reason_category == category.to_s
  end

  # Cached check for whether a reason requires an explanation
  def self.needs_explanation?(reason_name)
    explanation_map = Rails.cache.fetch("post_flag_reasons:for_needs_explanation") { ordered.pluck(:name, :needs_explanation).to_h }
    !!explanation_map[reason_name.to_s]
  end

  # Check if this reason has any children
  # Ideally, should not be called without preloding children
  def has_children?
    children.loaded ? children.any? : children.exists?
  end

  def self.invalidate_cache
    Rails.cache.delete("post_flag_reasons:for_radio")
    Rails.cache.delete("post_flag_reasons:for_name_validation")
    Rails.cache.delete("post_flag_reasons:for_needs_explanation")
  end
end
