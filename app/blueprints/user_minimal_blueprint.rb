# frozen_string_literal: true

class UserMinimalBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :level_string, :favorite_count
end
