# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           Comment Factory                                   #
# --------------------------------------------------------------------------- #

RSpec.describe Comment do
  include_context "as member"

  describe "factory" do
    it "produces a valid comment with build" do
      comment = build(:comment)
      expect(comment).to be_valid, comment.errors.full_messages.join(", ")
    end

    it "produces a valid comment with create" do
      comment = create(:comment)
      expect(comment).to be_persisted
    end

    it "produces a valid hidden comment" do
      comment = create(:hidden_comment)
      expect(comment).to be_persisted
      expect(comment.is_hidden).to be true
    end

    it "produces a valid sticky comment" do
      comment = create(:sticky_comment)
      expect(comment).to be_persisted
      expect(comment.is_sticky).to be true
    end

    it "produces a valid do_not_bump comment" do
      comment = create(:do_not_bump_comment)
      expect(comment).to be_persisted
      expect(comment.do_not_bump_post).to be true
    end
  end
end
