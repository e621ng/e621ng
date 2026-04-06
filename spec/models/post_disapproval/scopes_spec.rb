# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         PostDisapproval Scopes                              #
# --------------------------------------------------------------------------- #

RSpec.describe PostDisapproval do
  include_context "as member"

  def make_disapproval(overrides = {})
    create(:post_disapproval, **overrides)
  end

  # -------------------------------------------------------------------------
  # .with_message / .without_message
  # -------------------------------------------------------------------------
  describe ".with_message" do
    it "includes records with a non-empty message" do
      with = make_disapproval(message: "needs work")
      expect(PostDisapproval.with_message).to include(with)
    end

    it "excludes records with a nil message" do
      without = make_disapproval(message: nil)
      expect(PostDisapproval.with_message).not_to include(without)
    end

    it "excludes records with an empty-string message" do
      empty = make_disapproval(message: "")
      expect(PostDisapproval.with_message).not_to include(empty)
    end
  end

  describe ".without_message" do
    it "includes records with a nil message" do
      without = make_disapproval(message: nil)
      expect(PostDisapproval.without_message).to include(without)
    end

    it "includes records with an empty-string message" do
      empty = make_disapproval(message: "")
      expect(PostDisapproval.without_message).to include(empty)
    end

    it "excludes records with a non-empty message" do
      with = make_disapproval(message: "needs work")
      expect(PostDisapproval.without_message).not_to include(with)
    end
  end

  # -------------------------------------------------------------------------
  # .poor_quality / .not_relevant
  # -------------------------------------------------------------------------
  describe ".poor_quality" do
    it "includes records with reason 'borderline_quality'" do
      quality = make_disapproval(reason: "borderline_quality")
      expect(PostDisapproval.poor_quality).to include(quality)
    end

    it "excludes records with other reasons" do
      relevancy = make_disapproval(reason: "borderline_relevancy")
      other     = make_disapproval(reason: "other")
      expect(PostDisapproval.poor_quality).not_to include(relevancy, other)
    end
  end

  describe ".not_relevant" do
    it "includes records with reason 'borderline_relevancy'" do
      relevancy = make_disapproval(reason: "borderline_relevancy")
      expect(PostDisapproval.not_relevant).to include(relevancy)
    end

    it "excludes records with other reasons" do
      quality = make_disapproval(reason: "borderline_quality")
      other   = make_disapproval(reason: "other")
      expect(PostDisapproval.not_relevant).not_to include(quality, other)
    end
  end
end
