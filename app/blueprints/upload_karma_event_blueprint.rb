# frozen_string_literal: true

class UploadKarmaEventBlueprint < Blueprinter::Base
  identifier :id

  fields :user_id, :creator_id, :post_id, :reason, :delta, :balance, :extra_data, :created_at
end
