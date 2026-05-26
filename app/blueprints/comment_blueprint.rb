# frozen_string_literal: true

# Rubocop does not understand the Blueprinter block syntax
# rubocop:disable Style/SymbolProc

class CommentBlueprint < Blueprinter::Base
  identifier :id

  fields :created_at, :updated_at, :post_id, :creator_id, :body, :score,
         :updater_id, :do_not_bump_post, :is_hidden, :is_sticky,
         :warning_type, :warning_user_id

  field :creator_name do |comment|
    comment.creator_name
  end

  field :updater_name do |comment|
    comment.updater_name
  end

  field :vote do |comment|
    comment.vote_by
  end
end

# rubocop:enable Style/SymbolProc
