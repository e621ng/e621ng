# frozen_string_literal: true

class UserIpTouchCursor < ApplicationRecord
  self.primary_key = "source"

  validates :source, presence: true, uniqueness: true
  validates :cutoff_at, presence: true

  def self.cursor_for(source)
    find_or_create_by!(source: source) do |c|
      c.cutoff_at = 5.years.ago
    end
  end

  def advance!(last_processed_id: nil, last_processed_at: nil)
    self.last_processed_id = last_processed_id if last_processed_id
    self.last_processed_at = last_processed_at if last_processed_at
    save!
  end
end
