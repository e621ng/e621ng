# frozen_string_literal: true

class BulkUpdateRequestsUndo < ApplicationRecord
  belongs_to :bur_undo, polymorphic: true
end
