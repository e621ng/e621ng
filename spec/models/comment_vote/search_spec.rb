# frozen_string_literal: true

require "rails_helper"

RSpec.describe CommentVote do
  it_behaves_like "user_vote search: model_id",     :comment_vote, CommentVote
  it_behaves_like "user_vote search: user",         :comment_vote, CommentVote
  it_behaves_like "user_vote search: score",        :comment_vote, CommentVote
  it_behaves_like "user_vote search: timeframe",    :comment_vote, CommentVote
  it_behaves_like "user_vote search: user_ip_addr", :comment_vote, CommentVote
  it_behaves_like "user_vote search: order",        :comment_vote, CommentVote
end
