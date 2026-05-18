# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         UserFeedback.search                                 #
# --------------------------------------------------------------------------- #

RSpec.describe UserFeedback do
  let(:moderator)    { create(:moderator_user) }
  let(:subject_user) { create(:user) }

  before { CurrentUser.user = moderator }
  after  { CurrentUser.user = nil }

  def make_feedback(overrides = {})
    create(:user_feedback, user: subject_user, creator: moderator, **overrides)
  end

  describe ".search" do
    # -------------------------------------------------------------------------
    # deleted parameter
    # -------------------------------------------------------------------------
    describe "deleted parameter" do
      let!(:active)  { make_feedback(is_deleted: false) }
      let!(:deleted) { make_feedback(is_deleted: true) }

      it "excludes deleted records by default when the param is absent" do
        results = UserFeedback.search({})
        expect(results).to include(active)
        expect(results).not_to include(deleted)
      end

      it "excludes deleted records when deleted: 'excluded'" do
        results = UserFeedback.search(deleted: "excluded")
        expect(results).to include(active)
        expect(results).not_to include(deleted)
      end

      it "returns only deleted records when deleted: 'only'" do
        results = UserFeedback.search(deleted: "only")
        expect(results).to include(deleted)
        expect(results).not_to include(active)
      end

      it "returns all records when deleted is any other value" do
        results = UserFeedback.search(deleted: "included")
        expect(results).to include(active, deleted)
      end
    end

    # -------------------------------------------------------------------------
    # body_matches parameter
    # -------------------------------------------------------------------------
    describe "body_matches parameter" do
      let!(:matching)     { make_feedback(body: "positive contribution to the site") }
      let!(:nonmatching)  { make_feedback(body: "unrelated record") }

      it "returns records whose body matches the wildcard pattern" do
        results = UserFeedback.search(body_matches: "*contribution*")
        expect(results).to include(matching)
        expect(results).not_to include(nonmatching)
      end

      it "returns all records when body_matches is absent" do
        results = UserFeedback.search({})
        expect(results).to include(matching, nonmatching)
      end
    end

    # -------------------------------------------------------------------------
    # user filter (subject of feedback)
    # -------------------------------------------------------------------------
    describe "user filter" do
      let(:other_user)     { create(:user) }
      let!(:own_feedback)  { make_feedback(user: subject_user) }
      let!(:other_feedback) { make_feedback(user: other_user) }

      it "filters by user_name" do
        # Known bug: ApplicationController#with_resolved_user_ids only accepts string keys and values
        results = UserFeedback.search(user_name: subject_user.name)
        expect(results).to include(own_feedback)
        expect(results).not_to include(other_feedback)
      end

      it "filters by user_id" do
        # Known bug: ApplicationController#with_resolved_user_ids only accepts string keys and values
        results = UserFeedback.search(user_id: subject_user.id)
        expect(results).to include(own_feedback)
        expect(results).not_to include(other_feedback)
      end
    end

    # -------------------------------------------------------------------------
    # creator filter
    # -------------------------------------------------------------------------
    describe "creator filter" do
      let(:other_moderator)    { create(:moderator_user) }
      let!(:own_feedback)      { make_feedback(creator: moderator) }
      let!(:other_feedback)    { make_feedback(creator: other_moderator) }

      it "filters by creator_name" do
        # Known bug: ApplicationController#with_resolved_user_ids only accepts string keys and values
        results = UserFeedback.search(creator_name: moderator.name)
        expect(results).to include(own_feedback)
        expect(results).not_to include(other_feedback)
      end

      it "filters by creator_id" do
        # Known bug: ApplicationController#with_resolved_user_ids only accepts string keys and values
        results = UserFeedback.search(creator_id: moderator.id)
        expect(results).to include(own_feedback)
        expect(results).not_to include(other_feedback)
      end
    end

    # -------------------------------------------------------------------------
    # category parameter
    # -------------------------------------------------------------------------
    describe "category parameter" do
      let!(:positive) { make_feedback(category: "positive") }
      let!(:negative) { make_feedback(category: "negative") }
      let!(:neutral)  { make_feedback(category: "neutral") }

      it "returns only records of the given category" do
        results = UserFeedback.search(category: "positive")
        expect(results).to include(positive)
        expect(results).not_to include(negative, neutral)
      end

      it "returns all categories when the param is absent" do
        results = UserFeedback.search({})
        expect(results).to include(positive, negative, neutral)
      end
    end

    # -------------------------------------------------------------------------
    # order parameter (via apply_basic_order)
    # -------------------------------------------------------------------------
    describe "order parameter" do
      let!(:first)  { make_feedback }
      let!(:second) { make_feedback }

      it "returns records newest-first by default" do
        ids = UserFeedback.search({}).ids
        expect(ids.index(second.id)).to be < ids.index(first.id)
      end

      it "returns records oldest-first when order: 'id_asc'" do
        ids = UserFeedback.search(order: "id_asc").ids
        expect(ids.index(first.id)).to be < ids.index(second.id)
      end
    end
  end
end
