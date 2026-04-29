# frozen_string_literal: true

# Shared examples for UserVote base-class behaviour.
# Exercised through a concrete subclass (PostVote or CommentVote).
#
# Usage:
#
#   it_behaves_like "user_vote factory",          :post_vote, PostVote
#   it_behaves_like "user_vote score validation", :post_vote, PostVote
#   it_behaves_like "user_vote initialize",       :post_vote, PostVote
#   it_behaves_like "user_vote for_user scope",   :post_vote, PostVote
#   it_behaves_like "user_vote instance methods", :post_vote, PostVote
#   it_behaves_like "user_vote search: model_id", :post_vote, PostVote
#   it_behaves_like "user_vote search: user",     :post_vote, PostVote
#   it_behaves_like "user_vote search: score",    :post_vote, PostVote
#   it_behaves_like "user_vote search: timeframe",:post_vote, PostVote
#   it_behaves_like "user_vote search: order",    :post_vote, PostVote

# ---------------------------------------------------------------------------
# 1. Factory
# ---------------------------------------------------------------------------

RSpec.shared_examples "user_vote factory" do |factory_name, _model_class|
  include_context "as admin"

  describe "factory" do
    it "produces a valid, persisted record" do
      expect(create(factory_name)).to be_persisted
    end

    it "build produces a valid record" do
      expect(build(factory_name)).to be_valid
    end
  end
end

# ---------------------------------------------------------------------------
# 2. Score validation
# ---------------------------------------------------------------------------

RSpec.shared_examples "user_vote score validation" do |factory_name, _model_class|
  include_context "as admin"

  describe "score" do
    it "is valid with score 1" do
      expect(build(factory_name, score: 1)).to be_valid
    end

    it "is valid with score -1" do
      expect(build(factory_name, score: -1)).to be_valid
    end

    it "is valid with score 0" do
      expect(build(factory_name, score: 0)).to be_valid
    end

    it "is invalid with score 2" do
      record = build(factory_name, score: 2)
      expect(record).not_to be_valid
      expect(record.errors[:score]).to be_present
    end

    it "is invalid with score nil" do
      record = build(factory_name, score: nil)
      expect(record).not_to be_valid
      expect(record.errors[:score]).to be_present
    end
  end
end

# ---------------------------------------------------------------------------
# 3. initialize_attributes
# ---------------------------------------------------------------------------

RSpec.shared_examples "user_vote initialize" do |factory_name, model_class|
  include_context "as admin"

  describe "initialize_attributes" do
    it "sets user_id from CurrentUser when not explicitly given" do
      # Build without specifying a user so the after_initialize fallback fires.
      # We need to bypass other validations, so stub can_*_vote_with_reason.
      voter = create(:user)
      CurrentUser.user = voter

      # Build with a nil user_id; after_initialize should populate it.
      vote = model_class.new(score: 1)
      expect(vote.user_id).to eq(voter.id)
    end

    it "sets user_ip_addr from CurrentUser when not explicitly given" do
      CurrentUser.ip_addr = "10.0.0.1"
      vote = model_class.new(score: 1)
      expect(vote.user_ip_addr.to_s).to eq("10.0.0.1")
    end

    it "does not override an explicitly assigned user_id" do
      other_user = create(:user)
      vote = build(factory_name, user: other_user)
      expect(vote.user_id).to eq(other_user.id)
    end
  end
end

# ---------------------------------------------------------------------------
# 4. for_user scope
# ---------------------------------------------------------------------------

RSpec.shared_examples "user_vote for_user scope" do |factory_name, model_class|
  include_context "as admin"

  describe ".for_user" do
    it "returns votes belonging to the given user" do
      voter = create(:user)
      vote  = create(factory_name, user: voter)
      expect(model_class.for_user(voter.id)).to include(vote)
    end

    it "excludes votes from other users" do
      voter       = create(:user)
      other_voter = create(:user)
      _other_vote = create(factory_name, user: other_voter)
      expect(model_class.for_user(voter.id)).to be_empty
    end
  end
end

# ---------------------------------------------------------------------------
# 5. Instance methods: is_positive? / is_negative? / is_locked?
# ---------------------------------------------------------------------------

RSpec.shared_examples "user_vote instance methods" do |factory_name, _model_class|
  include_context "as admin"

  describe "#is_positive?" do
    it "returns true for score 1" do
      expect(create(factory_name, score: 1).is_positive?).to be true
    end

    it "returns false for score -1" do
      expect(create(factory_name, score: -1).is_positive?).to be false
    end

    it "returns false for score 0" do
      expect(create(factory_name, score: 0).is_positive?).to be false
    end
  end

  describe "#is_negative?" do
    it "returns true for score -1" do
      expect(create(factory_name, score: -1).is_negative?).to be true
    end

    it "returns false for score 1" do
      expect(create(factory_name, score: 1).is_negative?).to be false
    end

    it "returns false for score 0" do
      expect(create(factory_name, score: 0).is_negative?).to be false
    end
  end

  describe "#is_locked?" do
    it "returns true for score 0" do
      expect(create(factory_name, score: 0).is_locked?).to be true
    end

    it "returns false for score 1" do
      expect(create(factory_name, score: 1).is_locked?).to be false
    end

    it "returns false for score -1" do
      expect(create(factory_name, score: -1).is_locked?).to be false
    end
  end
end

# ---------------------------------------------------------------------------
# 6. Search: model_id param (post_id / comment_id)
# ---------------------------------------------------------------------------

RSpec.shared_examples "user_vote search: model_id" do |factory_name, model_class|
  include_context "as admin"

  # Derive the param name from the model type (e.g. PostVote => "post_id").
  let(:id_param) { "#{model_class.model_type}_id" }

  describe ".search (#{model_class.model_type}_id)" do
    it "returns votes for the specified model id" do
      vote  = create(factory_name)
      other = create(factory_name)
      model_id = vote.send("#{model_class.model_type}_id")

      result = model_class.search({ id_param => model_id.to_s }.with_indifferent_access)
      expect(result).to include(vote)
      expect(result).not_to include(other)
    end

    it "accepts a comma-separated list of ids" do
      vote_a = create(factory_name)
      vote_b = create(factory_name)
      other  = create(factory_name)

      id_a = vote_a.send("#{model_class.model_type}_id")
      id_b = vote_b.send("#{model_class.model_type}_id")

      result = model_class.search({ id_param => "#{id_a},#{id_b}" }.with_indifferent_access)
      expect(result).to include(vote_a, vote_b)
      expect(result).not_to include(other)
    end
  end
end

# ---------------------------------------------------------------------------
# 7. Search: user param
# ---------------------------------------------------------------------------

RSpec.shared_examples "user_vote search: user" do |factory_name, model_class|
  include_context "as admin"

  let(:id_param) { "#{model_class.model_type}_id" }

  describe ".search (user)" do
    it "filters by user_id" do
      voter    = create(:user)
      vote     = create(factory_name, user: voter)
      _other   = create(factory_name)
      model_id = vote.send("#{model_class.model_type}_id")

      result = model_class.search({ id_param => model_id.to_s, "user_id" => voter.id.to_s }.with_indifferent_access)
      expect(result).to include(vote)
    end

    it "filters by user_name" do
      voter    = create(:user)
      vote     = create(factory_name, user: voter)
      model_id = vote.send("#{model_class.model_type}_id")

      result = model_class.search({ id_param => model_id.to_s, "user_name" => voter.name }.with_indifferent_access)
      expect(result).to include(vote)
    end
  end
end

# ---------------------------------------------------------------------------
# 8. Search: score param
# ---------------------------------------------------------------------------

RSpec.shared_examples "user_vote search: score" do |factory_name, model_class|
  include_context "as admin"

  let(:id_param) { "#{model_class.model_type}_id" }

  describe ".search (score)" do
    it "returns only votes with the given score" do
      up_vote   = create(factory_name, score: 1)
      down_vote = create(factory_name, score: -1)
      model_id  = up_vote.send("#{model_class.model_type}_id")

      result = model_class.search({ id_param => model_id.to_s, score: "1" }.with_indifferent_access)
      expect(result).to include(up_vote)
      expect(result).not_to include(down_vote)
    end
  end
end

# ---------------------------------------------------------------------------
# 9. Search: timeframe param
# ---------------------------------------------------------------------------

RSpec.shared_examples "user_vote search: timeframe" do |factory_name, model_class|
  include_context "as admin"

  let(:id_param) { "#{model_class.model_type}_id" }

  describe ".search (timeframe)" do
    it "excludes votes older than the timeframe" do
      recent = create(factory_name)
      old    = create(factory_name)
      old.update_columns(updated_at: 5.days.ago)

      model_id = recent.send("#{model_class.model_type}_id")
      result = model_class.search({ id_param => model_id.to_s, timeframe: "2" }.with_indifferent_access)
      expect(result).to include(recent)
      expect(result).not_to include(old)
    end
  end
end

# ---------------------------------------------------------------------------
# 10. Search: user_ip_addr param
# ---------------------------------------------------------------------------

RSpec.shared_examples "user_vote search: user_ip_addr" do |factory_name, model_class|
  include_context "as admin"

  let(:id_param) { "#{model_class.model_type}_id" }

  describe ".search (user_ip_addr)" do
    it "returns votes from the given IP subnet" do
      vote  = create(factory_name)
      other = create(factory_name)
      vote.update_columns(user_ip_addr: "10.1.2.3")
      other.update_columns(user_ip_addr: "192.168.0.1")
      model_id = vote.send("#{model_class.model_type}_id")

      result = model_class.search({ id_param => model_id.to_s, user_ip_addr: "10.1.2.0/24" }.with_indifferent_access)
      expect(result).to include(vote)
      expect(result).not_to include(other)
    end
  end
end

# ---------------------------------------------------------------------------
# 11. Search: order param
# ---------------------------------------------------------------------------

RSpec.shared_examples "user_vote search: order" do |factory_name, model_class|
  include_context "as admin"

  let(:id_param) { "#{model_class.model_type}_id" }

  describe ".search (order)" do
    it "orders by id descending by default" do
      older = create(factory_name)
      newer = create(factory_name)
      ids = model_class.search({}).ids
      expect(ids.index(newer.id)).to be < ids.index(older.id)
    end

    it "orders by user_ip_addr when order=ip_addr" do
      vote_a = create(factory_name)
      vote_a.update_columns(user_ip_addr: "10.0.0.1")
      vote_b = create(factory_name)
      vote_b.update_columns(user_ip_addr: "10.0.0.2")

      model_id = vote_a.send("#{model_class.model_type}_id")
      result = model_class.search({ id_param => model_id.to_s, order: "ip_addr" }.with_indifferent_access).ids
      expect(result).to include(vote_a.id)
    end
  end
end
