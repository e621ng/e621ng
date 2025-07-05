# frozen_string_literal: true

class PostReportReason < ApplicationRecord
  belongs_to_creator
  validates :reason, uniqueness: { case_sensitive: false }

  def self.for_radio
    @for_radio ||= order("id DESC").to_a
  end
end
