# frozen_string_literal: true

# Pass `subscriptions: Artist.subscription_info(artists, user)` so they're loaded in bulk
class ArtistBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :creator_id, :is_active, :group_name, :created_at, :updated_at,
         :other_names, :linked_user_id, :is_locked, :notes

  field :subscription_count do |artist, options|
    options[:subscriptions][artist.id][:subscription_count]
  end

  field :subscribed do |artist, options|
    options[:subscriptions][artist.id][:subscribed]
  end

  association :urls, blueprint: ArtistUrlBlueprint

  view :with_domains do
    field :domains
  end
end
