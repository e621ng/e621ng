# frozen_string_literal: true

class EditHistory < ApplicationRecord
  self.table_name = 'edit_histories'
  belongs_to :versionable, polymorphic: true
  belongs_to :user

  TYPE_MAP = {
      comment: 'Comment',
      forum: 'ForumPost',
      blip: 'Blip'
  }
end
