# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostVote do
  it_behaves_like "user_vote search: model_id",     :post_vote, PostVote
  it_behaves_like "user_vote search: user",         :post_vote, PostVote
  it_behaves_like "user_vote search: score",        :post_vote, PostVote
  it_behaves_like "user_vote search: timeframe",    :post_vote, PostVote
  it_behaves_like "user_vote search: user_ip_addr", :post_vote, PostVote
  it_behaves_like "user_vote search: order",        :post_vote, PostVote
end
