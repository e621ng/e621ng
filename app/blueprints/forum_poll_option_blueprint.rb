# frozen_string_literal: true

class ForumPollOptionBlueprint < Blueprinter::Base
  identifier :id

  fields :position, :body, :vote_count

  # Individual ballots are visible to moderators and above; IPs only to admins.
  field :voters, if: ->(_name, _option, options) { options[:staff] } do |option, options|
    option.votes.includes(:user).map do |vote|
      voter = { user_id: vote.user_id, user_name: vote.user&.name, created_at: vote.created_at }
      voter[:user_ip_addr] = vote.user_ip_addr if options[:admin]
      voter
    end
  end
end
