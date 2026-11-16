# frozen_string_literal: true

# Rubocop does not understand the Blueprinter block syntax
# rubocop:disable Style/SymbolProc

class ForumPollBlueprint < Blueprinter::Base
  identifier :id

  fields :forum_topic_id, :creator_id, :max_choices, :expires_at, :closed_early_by_id,
         :voter_count, :created_at, :updated_at

  field :is_open do |poll|
    poll.open?
  end

  association :options, blueprint: ForumPollOptionBlueprint
end

# rubocop:enable Style/SymbolProc
