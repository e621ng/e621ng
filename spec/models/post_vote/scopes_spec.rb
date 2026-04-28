# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostVote do
  it_behaves_like "user_vote for_user scope", :post_vote, PostVote
end
