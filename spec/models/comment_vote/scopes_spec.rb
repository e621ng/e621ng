# frozen_string_literal: true

require "rails_helper"

RSpec.describe CommentVote do
  it_behaves_like "user_vote for_user scope", :comment_vote, CommentVote
end
