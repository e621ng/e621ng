# frozen_string_literal: true

class StaffWikiRef < ApplicationRecord
  ALLOWED_TYPES = %w[User Artist StaffWiki].freeze

  belongs_to :staff_wiki
  belongs_to :related, polymorphic: true

  validates :related_type, presence: true, inclusion: { in: ALLOWED_TYPES }
end
