# frozen_string_literal: true

class PostFlagReason < ApplicationRecord
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :reason, presence: true
  validates :index, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :target_date_kind, inclusion: { in: %w[before after], allow_blank: true }

  after_destroy -> { self.class.invalidate_cache }
  after_save -> { self.class.invalidate_cache }
  # TODO: Log ModAction for changes to flag reasons, similar to report reasons

  scope :ordered, -> { order(index: :asc, id: :asc) }

  # Cached list of reasons for use in radio buttons
  # Structured to include sub-reasons as children
  def self.for_radio
    Rails.cache.fetch("post_flag_reasons:for_radio") do
      ordered.to_a
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

  # Cached check for whether a reason requires an explanation
  def self.reason(reason_name)
    reason_map = Rails.cache.fetch("post_flag_reasons:for_reason") { ordered.pluck(:name, :reason).to_h }
    reason_map[reason_name.to_s]
  end

  def self.invalidate_cache
    Rails.cache.delete("post_flag_reasons:for_radio")
    Rails.cache.delete("post_flag_reasons:for_name_validation")
    Rails.cache.delete("post_flag_reasons:for_needs_explanation")
  end
end
