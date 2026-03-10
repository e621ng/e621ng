# frozen_string_literal: true

require "timeout"

class AutomodRule < ApplicationRecord
  belongs_to_creator

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :regex, presence: true
  validate :validate_regex

  scope :enabled, -> { where(enabled: true) }

  def match?(text)
    Regexp.new(regex, Regexp::IGNORECASE).match?(text)
  rescue RegexpError
    false
  end

  private

  def validate_regex
    return if regex.blank?

    compiled = Regexp.new(regex, Regexp::IGNORECASE)
    Timeout.timeout(0.5) { compiled.match?("#{'a' * 100}\u0000") }
  rescue RegexpError => e
    errors.add(:regex, "is invalid: #{e.message}")
  rescue Timeout::Error
    errors.add(:regex, "causes catastrophic backtracking and cannot be used")
  end
end
