# frozen_string_literal: true

class PostFlagReason < ApplicationRecord
  self.inheritance_column = :_type_disabled

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :reason, presence: true

  scope :ordered, -> { order(index: :asc, id: :asc) }
  scope :for_flags, -> { where(type: "flag") }
  scope :for_reports, -> { where(type: "report") }

  def self.for_radio
    key = [name, :for_radio, :flags, ordered.cache_key]
    Rails.cache.fetch(key) { ordered.to_a }
  end

  # Cached mapping of name => reason for validations and display
  def self.map_for_lookup
    key = [name, :map_for_lookup, :flags, ordered.cache_key]
    Rails.cache.fetch(key) { ordered.pluck(:name, :reason).to_h }
  end

  # Cached check for whether a reason requires an explanation
  def self.require_explanation?(reason_name)
    key = [name, :require_explanation_map, :flags, ordered.cache_key]
    explanation_map = Rails.cache.fetch(key) { ordered.pluck(:name, :require_explanation).to_h }
    !!explanation_map[reason_name.to_s]
  end
end
