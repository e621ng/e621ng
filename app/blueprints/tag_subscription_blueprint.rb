# frozen_string_literal: true

class TagSubscriptionBlueprint < Blueprinter::Base
  identifier :id

  fields :tag_id, :created_at

  field(:tag_name) { |sub, _options| sub.tag.name }
  field(:category) { |sub, _options| sub.tag.category }
end
