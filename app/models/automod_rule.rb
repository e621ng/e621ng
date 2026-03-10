# frozen_string_literal: true

class AutomodRule < ApplicationRecord
  belongs_to_creator

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :regex, presence: true
  validate :validate_regex

  scope :enabled, -> { where(enabled: true) }

  def match?(text)
    Regexp.new(regex).match?(text)
  rescue RegexpError
    false
  end

  private

  def validate_regex
    return if regex.blank?
    Regexp.new(regex)
  rescue RegexpError => e
    errors.add(:regex, "is invalid: #{e.message}")
  end
end
