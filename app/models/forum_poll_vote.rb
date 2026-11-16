# frozen_string_literal: true

# One row per (voter, selected option). Rows are normally written in bulk by
# ForumPoll#cast_ballot!; the model exists for reads, factories, and staff views.
class ForumPollVote < ApplicationRecord
  belongs_to :poll, class_name: "ForumPoll", foreign_key: :forum_poll_id
  belongs_to :option, class_name: "ForumPollOption", foreign_key: :forum_poll_option_id
  belongs_to :user

  validates :user_id, uniqueness: { scope: :forum_poll_option_id }
end
