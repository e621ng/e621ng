# frozen_string_literal: true

class DbExportBlueprint < Blueprinter::Base
  field :name
  field :file_name
  field :file_size
  field :checksum
  field :updated_at
  field :url
end
