# frozen_string_literal: true

require "rails_helper"

RSpec.describe CommentVote do
  include_context "as admin"

  it_behaves_like "user_vote instance methods", :comment_vote, CommentVote
  it_behaves_like "user_vote initialize",       :comment_vote, CommentVote

  # -------------------------------------------------------------------------
  # CommentVote-specific class methods
  # -------------------------------------------------------------------------
  describe ".model_type" do
    it "returns :comment" do
      expect(CommentVote.model_type).to eq(:comment)
    end
  end

  describe ".model_creator_column" do
    it "returns :creator" do
      expect(CommentVote.model_creator_column).to eq(:creator)
    end
  end
end
