# frozen_string_literal: true

class SavedSearchBlueprint < Blueprinter::Base
  identifier :id

  fields :query, :name, :is_tracked, :last_seen_post_id, :created_at, :updated_at

  field :new_count do |saved_search, options|
    options[:counts].is_a?(Hash) ? options[:counts][saved_search.id] : nil
  end
end
