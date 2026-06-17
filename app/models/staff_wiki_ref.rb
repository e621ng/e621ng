# frozen_string_literal: true

class StaffWikiRef < ApplicationRecord
  ALLOWED_TYPES = %w[User Artist StaffWiki].freeze

  belongs_to :staff_wiki
  belongs_to :related, polymorphic: true

  validates :related_type, presence: true, inclusion: { in: ALLOWED_TYPES }
  validate :validate_related_exists

  def validate_related_exists
    return if related_type.blank? || related_id.blank?

    unless related_type.constantize.exists?(related_id)
      errors.add(:base, "Related #{related_type} does not exist")
    end
  end
end
