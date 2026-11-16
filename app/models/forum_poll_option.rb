# frozen_string_literal: true

class ForumPollOption < ApplicationRecord
  belongs_to :poll, class_name: "ForumPoll", foreign_key: :forum_poll_id, inverse_of: :options
  has_many :votes, class_name: "ForumPollVote", dependent: :delete_all

  validates :body, presence: true, length: { maximum: ->(_record) { Danbooru.config.forum_poll_option_max_size } }

  # Share of voters, not of votes: multi-select bars may sum past 100%.
  def percentage(voter_count = poll.voter_count)
    return 0 if voter_count.to_i == 0
    (vote_count * 100.0 / voter_count).round
  end
end
