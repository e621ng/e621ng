# frozen_string_literal: true

class PostReplacementNote < ApplicationRecord
  belongs_to :post_replacement, foreign_key: :post_replacements2_id
  validates :post_replacements2_id, uniqueness: true
  validates :note, length: { maximum: 1000 }, allow_blank: true

  def visible_to?(user)
    user.id == post_replacement.creator_id || user.is_staff?
  end

  def self.create_or_update_for_replacement!(_user, post_replacement, note_content)
    note = post_replacement.note
    if note.present?
      note.update!(note: note_content)
    else
      note = create!(post_replacement: post_replacement, note: note_content)
      post_replacement.note = note
    end
    note
  end
end
