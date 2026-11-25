# frozen_string_literal: true

class ArtistUrlBlueprint < Blueprinter::Base
  identifier :id

  fields :artist_id, :url, :normalized_url, :created_at, :updated_at, :is_active
end
