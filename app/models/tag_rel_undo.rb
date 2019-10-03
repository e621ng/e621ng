class TagRelUndo < ApplicationRecord
  belongs_to :tag_rel, polymorphic: true
end
