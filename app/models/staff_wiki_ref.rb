# frozen_string_literal: true

class StaffWikiRef < ApplicationRecord
  ALLOWED_TYPES = %w[User Artist StaffWiki].freeze

  belongs_to :staff_wiki
  belongs_to :related, polymorphic: true

  validates :related_type, presence: true, inclusion: { in: ALLOWED_TYPES }

  module ValidationMethods
    def validate_related_exists
      return if related_type.blank? || related_id.blank?
      return unless ALLOWED_TYPES.include?(related_type)

      unless related_type.constantize.exists?(related_id)
        errors.add(:related_id, "must refer to an existing #{related_type}")
      end
    end
  end

  include ValidationMethods
end
