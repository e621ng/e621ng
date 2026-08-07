# frozen_string_literal: true

class BanBlueprint < Blueprinter::Base
  identifier :id

  field :user_id
  field :banner_id
  field :reason

  field :expires_at
  field :created_at
  field :updated_at
end
