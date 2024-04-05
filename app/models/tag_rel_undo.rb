# frozen_string_literal: true

class TagRelUndo < ApplicationRecord
  belongs_to :tag_rel, polymorphic: true
end
