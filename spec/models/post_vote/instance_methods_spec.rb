# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostVote do
  it_behaves_like "user_vote instance methods", :post_vote, PostVote
  it_behaves_like "user_vote initialize",       :post_vote, PostVote

  # -------------------------------------------------------------------------
  # PostVote-specific class methods
  # -------------------------------------------------------------------------
  describe ".model_type" do
    it "returns :post" do
      expect(PostVote.model_type).to eq(:post)
    end
  end

  describe ".model_creator_column" do
    it "returns :uploader" do
      expect(PostVote.model_creator_column).to eq(:uploader)
    end
  end
end
