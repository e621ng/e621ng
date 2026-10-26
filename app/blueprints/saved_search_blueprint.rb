# frozen_string_literal: true

class SavedSearchBlueprint < Blueprinter::Base
  identifier :id

  fields :query, :name, :is_tracked, :is_subscription, :last_seen_post_id, :created_at, :updated_at

  field :tag_count, if: ->(_field, saved_search, _options) { saved_search.is_subscription? } do |saved_search, _options|
    TagSubscription.where(user_id: saved_search.user_id).count
  end

  field :new_count do |saved_search, options|
    options[:counts].is_a?(Hash) ? options[:counts][saved_search.id] : nil
  end
end
