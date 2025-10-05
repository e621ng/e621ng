# frozen_string_literal: true

class PostFlagReason < ApplicationRecord
  self.inheritance_column = :_type_disabled

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :reason, presence: true

  after_destroy :invalidate_cache
  after_save :invalidate_cache

  scope :ordered, -> { order(index: :asc, id: :asc) }
  scope :for_flags, -> { where(type: "flag") }
  scope :for_reports, -> { where(type: "report") }

  def self.for_radio
    Rails.cache.fetch("post_flag_reasons:for_radio") { ordered.to_a }
  end

  # Cached mapping of name => reason for validations and display
  def self.map_for_lookup
    Rails.cache.fetch("post_flag_reasons:map_for_lookup") { ordered.pluck(:name, :reason).to_h }
  end

  # Cached check for whether a reason requires an explanation
  def self.needs_explanation?(reason_name)
    explanation_map = Rails.cache.fetch("post_flag_reasons:needs_explanation_map") { ordered.pluck(:name, :needs_explanation).to_h }
    !!explanation_map[reason_name.to_s]
  end

  private

  def invalidate_cache
    Rails.cache.delete("post_flag_reasons:for_radio")
    Rails.cache.delete("post_flag_reasons:map_for_lookup")
    Rails.cache.delete("post_flag_reasons:needs_explanation_map")
  end
end
