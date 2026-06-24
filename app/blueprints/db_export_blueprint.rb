# frozen_string_literal: true

class DbExportBlueprint < Blueprinter::Base
  identifier :id

  field :name
  field :file_name
  field :file_size
  field :checksum
  field :updated_at
  field :url
end
