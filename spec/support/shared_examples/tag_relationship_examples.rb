# frozen_string_literal: true

# Shared examples for TagRelationship base-class behavior.
# Exercised through a concrete subclass (TagAlias or TagImplication).
#
# Usage in a *_spec.rb file:
#
#   it_behaves_like "tag_relationship factory",          :tag_alias, TagAlias
#   it_behaves_like "tag_relationship validations",      :tag_alias, TagAlias
#   it_behaves_like "tag_relationship normalizations",   :tag_alias, TagAlias
#   it_behaves_like "tag_relationship scopes",           :tag_alias, TagAlias
#   it_behaves_like "tag_relationship instance methods", :tag_alias, TagAlias
#   it_behaves_like "tag_relationship search",           :tag_alias, TagAlias
#   it_behaves_like "tag_relationship message methods",  :tag_alias, TagAlias

# ---------------------------------------------------------------------------
# 1. Factory
# ---------------------------------------------------------------------------

RSpec.shared_examples "tag_relationship factory" do |factory_name, _model_class|
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
# 2. Validations
# ---------------------------------------------------------------------------

RSpec.shared_examples "tag_relationship validations" do |factory_name, _model_class|
  include_context "as admin"

  describe "validations" do
    # -------------------------------------------------------------------------
    # status
    # -------------------------------------------------------------------------
    describe "status" do
      it "is valid for each recognised status value" do
        %w[active deleted pending processing queued retired].each do |status|
          record = build(factory_name, status: status)
          record.valid?
          expect(record.errors[:status]).to be_empty,
                                            "expected status '#{status}' to be valid but got: #{record.errors[:status].join(', ')}"
        end
      end

      it "accepts a status beginning with 'error: '" do
        record = build(factory_name, status: "error: something went wrong")
        record.valid?
        expect(record.errors[:status]).to be_empty
      end

      it "is invalid with a blank status" do
        record = build(factory_name, status: "")
        expect(record).not_to be_valid
        expect(record.errors[:status]).to be_present
      end

      it "is invalid with an unrecognised status" do
        record = build(factory_name, status: "unknown_status")
        expect(record).not_to be_valid
        expect(record.errors[:status]).to be_present
      end
    end

    # -------------------------------------------------------------------------
    # antecedent_name / consequent_name — presence
    # -------------------------------------------------------------------------
    describe "antecedent_name" do
      it "is invalid when antecedent_name is blank" do
        record = build(factory_name, antecedent_name: "")
        expect(record).not_to be_valid
        expect(record.errors[:antecedent_name]).to be_present
      end
    end

    describe "consequent_name" do
      it "is invalid when consequent_name is blank" do
        record = build(factory_name, consequent_name: "")
        expect(record).not_to be_valid
        expect(record.errors[:consequent_name]).to be_present
      end
    end

    # -------------------------------------------------------------------------
    # creator_id — presence
    # -------------------------------------------------------------------------
    describe "creator_id" do
      it "is invalid without a creator_id on a persisted record" do
        record = create(factory_name)
        record.creator_id = nil
        expect(record).not_to be_valid
        expect(record.errors[:creator_id]).to be_present
      end
    end

    # -------------------------------------------------------------------------
    # creator — referential integrity
    # -------------------------------------------------------------------------
    describe "creator referential integrity" do
      it "is invalid when creator_id references a non-existent user" do
        record = create(factory_name)
        record.creator_id = -1
        expect(record).not_to be_valid
        expect(record.errors[:creator]).to include("must exist")
      end
    end

    # -------------------------------------------------------------------------
    # approver — referential integrity (only checked when approver_id is set)
    # -------------------------------------------------------------------------
    describe "approver referential integrity" do
      it "is invalid when approver_id references a non-existent user" do
        record = build(factory_name)
        record.approver_id = -1
        expect(record).not_to be_valid
        expect(record.errors[:approver]).to include("must exist")
      end

      it "is valid when approver_id is absent" do
        record = build(factory_name)
        expect(record.approver_id).to be_nil
        expect(record).to be_valid
      end
    end

    # -------------------------------------------------------------------------
    # forum_topic — referential integrity (only checked when forum_topic_id is set)
    # -------------------------------------------------------------------------
    describe "forum_topic referential integrity" do
      it "is invalid when forum_topic_id references a non-existent topic" do
        record = build(factory_name)
        record.forum_topic_id = -1
        expect(record).not_to be_valid
        expect(record.errors[:forum_topic]).to include("must exist")
      end
    end

    # -------------------------------------------------------------------------
    # validate_creator_is_not_limited (on: :create)
    # -------------------------------------------------------------------------
    describe "validate_creator_is_not_limited" do
      it "is invalid on create when the creator has hit the suggestion limit" do
        limited_user = create(:user)
        limited_user.update_columns(created_at: 2.weeks.ago)
        allow(limited_user).to receive(:can_suggest_tag_with_reason).and_return(:REJ_LIMITED)
        CurrentUser.user = limited_user

        record = build(factory_name)
        # Prime the association cache so the stub applies — without this,
        # record.creator performs a DB lookup and returns a different Ruby object.
        record.creator = limited_user
        expect(record).not_to be_valid
        expect(record.errors[:creator]).to be_present
      end

      it "does not re-run the limit check on update" do
        record = create(factory_name)
        allow(record.creator).to receive(:can_suggest_tag_with_reason).and_return(:REJ_LIMITED)
        record.status = "pending"
        expect(record).to be_valid
      end
    end

    # -------------------------------------------------------------------------
    # antecedent_and_consequent_are_different
    # -------------------------------------------------------------------------
    describe "antecedent_and_consequent_are_different" do
      it "is invalid when antecedent_name equals consequent_name" do
        record = build(factory_name, antecedent_name: "same_tag", consequent_name: "same_tag")
        expect(record).not_to be_valid
        expect(record.errors[:base]).to include("Cannot alias or implicate a tag to itself")
      end

      it "is valid when antecedent_name differs from consequent_name" do
        record = build(factory_name)
        record.valid?
        expect(record.errors[:base]).not_to include("Cannot alias or implicate a tag to itself")
      end
    end

    # -------------------------------------------------------------------------
    # consequent_name — tag_name format (checked on change)
    # -------------------------------------------------------------------------
    describe "consequent_name tag_name format" do
      it "is invalid when consequent_name starts with a dash" do
        record = build(factory_name, consequent_name: "-invalid_tag")
        expect(record).not_to be_valid
        expect(record.errors[:consequent_name]).to be_present
      end

      it "is valid with a well-formed consequent_name" do
        record = build(factory_name)
        expect(record).to be_valid
      end
    end
  end
end

# ---------------------------------------------------------------------------
# 3. Normalizations
# ---------------------------------------------------------------------------

RSpec.shared_examples "tag_relationship normalizations" do |factory_name, _model_class|
  include_context "as admin"

  describe "normalizations (normalize_names before_validation)" do
    it "downcases antecedent_name" do
      record = build(factory_name, antecedent_name: "UPPER_ANTECEDENT")
      record.valid?
      expect(record.antecedent_name).to eq("upper_antecedent")
    end

    it "downcases consequent_name" do
      record = build(factory_name, consequent_name: "UPPER_CONSEQUENT")
      record.valid?
      expect(record.consequent_name).to eq("upper_consequent")
    end

    it "converts spaces to underscores in antecedent_name" do
      record = build(factory_name, antecedent_name: "tag with spaces")
      record.valid?
      expect(record.antecedent_name).to eq("tag_with_spaces")
    end

    it "converts spaces to underscores in consequent_name" do
      record = build(factory_name, consequent_name: "tag with spaces")
      record.valid?
      expect(record.consequent_name).to eq("tag_with_spaces")
    end
  end
end

# ---------------------------------------------------------------------------
# 4. Scopes
# ---------------------------------------------------------------------------

RSpec.shared_examples "tag_relationship scopes" do |factory_name, model_class|
  include_context "as admin"

  # Force a status without re-running validations.
  def make_with_status(factory_name, status)
    create(factory_name).tap { |r| r.update_columns(status: status) }
  end

  describe "scopes" do
    # -------------------------------------------------------------------------
    # .approved / .active
    # -------------------------------------------------------------------------
    describe ".approved" do
      let!(:active_record)     { make_with_status(factory_name, "active") }
      let!(:processing_record) { make_with_status(factory_name, "processing") }
      let!(:queued_record)     { make_with_status(factory_name, "queued") }
      let!(:pending_record)    { create(factory_name) }
      let!(:deleted_record)    { make_with_status(factory_name, "deleted") }
      let!(:retired_record)    { make_with_status(factory_name, "retired") }

      it "includes active, processing, and queued records" do
        expect(model_class.approved).to include(active_record, processing_record, queued_record)
      end

      it "excludes pending, deleted, and retired records" do
        expect(model_class.approved).not_to include(pending_record, deleted_record, retired_record)
      end
    end

    describe ".active" do
      it "is an alias for .approved" do
        active_rec  = make_with_status(factory_name, "active")
        pending_rec = create(factory_name)

        expect(model_class.active).to include(active_rec)
        expect(model_class.active).not_to include(pending_rec)
      end
    end

    # -------------------------------------------------------------------------
    # .pending
    # -------------------------------------------------------------------------
    describe ".pending" do
      let!(:pending_record) { create(factory_name) }
      let!(:active_record)  { make_with_status(factory_name, "active") }

      it "returns only pending records" do
        expect(model_class.pending).to include(pending_record)
        expect(model_class.pending).not_to include(active_record)
      end
    end

    # -------------------------------------------------------------------------
    # .deleted
    # -------------------------------------------------------------------------
    describe ".deleted" do
      let!(:deleted_record) { make_with_status(factory_name, "deleted") }
      let!(:pending_record) { create(factory_name) }

      it "returns only deleted records" do
        expect(model_class.deleted).to include(deleted_record)
        expect(model_class.deleted).not_to include(pending_record)
      end
    end

    # -------------------------------------------------------------------------
    # .retired
    # -------------------------------------------------------------------------
    describe ".retired" do
      let!(:retired_record) { make_with_status(factory_name, "retired") }
      let!(:pending_record) { create(factory_name) }

      it "returns only retired records" do
        expect(model_class.retired).to include(retired_record)
        expect(model_class.retired).not_to include(pending_record)
      end
    end

    # -------------------------------------------------------------------------
    # .duplicate_relevant
    # -------------------------------------------------------------------------
    describe ".duplicate_relevant" do
      let!(:active_record)     { make_with_status(factory_name, "active") }
      let!(:processing_record) { make_with_status(factory_name, "processing") }
      let!(:queued_record)     { make_with_status(factory_name, "queued") }
      let!(:pending_record)    { create(factory_name) }
      let!(:deleted_record)    { make_with_status(factory_name, "deleted") }
      let!(:retired_record)    { make_with_status(factory_name, "retired") }

      it "includes active, processing, queued, and pending records" do
        expect(model_class.duplicate_relevant).to include(active_record, processing_record, queued_record, pending_record)
      end

      it "excludes deleted and retired records" do
        expect(model_class.duplicate_relevant).not_to include(deleted_record, retired_record)
      end
    end
  end
end

# ---------------------------------------------------------------------------
# 5. Instance Methods
# ---------------------------------------------------------------------------

RSpec.shared_examples "tag_relationship instance methods" do |factory_name, _model_class|
  include_context "as admin"

  describe "instance methods" do
    # -------------------------------------------------------------------------
    # Status predicate methods (operate purely on the status string)
    # -------------------------------------------------------------------------
    describe "#is_approved?" do
      it "returns true for active, processing, and queued" do
        %w[active processing queued].each do |status|
          record = build(factory_name)
          record.status = status
          expect(record.is_approved?).to be(true),
                                         "expected is_approved? to be true for status '#{status}'"
        end
      end

      it "returns false for pending, deleted, and retired" do
        %w[pending deleted retired].each do |status|
          record = build(factory_name)
          record.status = status
          expect(record.is_approved?).to be(false),
                                         "expected is_approved? to be false for status '#{status}'"
        end
      end
    end

    describe "#is_pending?" do
      it "returns true when status is pending" do
        record = build(factory_name)
        record.status = "pending"
        expect(record.is_pending?).to be(true)
      end

      it "returns false for other statuses" do
        record = build(factory_name)
        record.status = "active"
        expect(record.is_pending?).to be(false)
      end
    end

    describe "#is_deleted?" do
      it "returns true when status is deleted" do
        record = build(factory_name)
        record.status = "deleted"
        expect(record.is_deleted?).to be(true)
      end

      it "returns false for other statuses" do
        record = build(factory_name)
        record.status = "active"
        expect(record.is_deleted?).to be(false)
      end
    end

    describe "#is_retired?" do
      it "returns true when status is retired" do
        record = build(factory_name)
        record.status = "retired"
        expect(record.is_retired?).to be(true)
      end

      it "returns false for other statuses" do
        record = build(factory_name)
        record.status = "active"
        expect(record.is_retired?).to be(false)
      end
    end

    describe "#is_active?" do
      it "returns true when status is active" do
        record = build(factory_name)
        record.status = "active"
        expect(record.is_active?).to be(true)
      end

      it "returns false for other statuses" do
        record = build(factory_name)
        record.status = "pending"
        expect(record.is_active?).to be(false)
      end
    end

    describe "#is_errored?" do
      it "returns true when status starts with 'error:'" do
        record = build(factory_name)
        record.status = "error: something went wrong"
        expect(record).to be_is_errored
      end

      it "returns false for non-error statuses" do
        record = build(factory_name)
        record.status = "active"
        expect(record).not_to be_is_errored
      end
    end

    # -------------------------------------------------------------------------
    # Authorization methods
    # -------------------------------------------------------------------------
    describe "#approvable_by?" do
      let(:record) { create(factory_name) } # pending by default
      let(:admin)  { create(:admin_user) }
      let(:member) { create(:user) }

      it "returns true for an admin when the record is pending" do
        expect(record.approvable_by?(admin)).to be(true)
      end

      it "returns false for a regular member" do
        expect(record.approvable_by?(member)).to be(false)
      end

      it "returns false for an admin when the record is not pending" do
        record.update_columns(status: "active")
        expect(record.approvable_by?(admin)).to be(false)
      end
    end

    describe "#deletable_by?" do
      let(:record) { create(factory_name) } # pending by default
      let(:admin)  { create(:admin_user) }
      let(:member) { create(:user) }

      it "returns true for an admin when the record is not deleted" do
        expect(record.deletable_by?(admin)).to be(true)
      end

      it "returns false for an admin when the record is already deleted" do
        record.update_columns(status: "deleted")
        expect(record.deletable_by?(admin)).to be(false)
      end

      it "returns true for the creator when the record is pending" do
        expect(record.deletable_by?(record.creator)).to be(true)
      end

      it "returns false for a non-creator member" do
        expect(record.deletable_by?(member)).to be(false)
      end
    end

    describe "#editable_by?" do
      let(:record) { create(factory_name) } # pending by default
      let(:admin)  { create(:admin_user) }
      let(:member) { create(:user) }

      it "returns true for an admin when the record is pending" do
        expect(record.editable_by?(admin)).to be(true)
      end

      it "returns false for a regular member" do
        expect(record.editable_by?(member)).to be(false)
      end

      it "returns false for an admin when the record is not pending" do
        record.update_columns(status: "active")
        expect(record.editable_by?(admin)).to be(false)
      end
    end
  end
end

# ---------------------------------------------------------------------------
# 6. Search
# ---------------------------------------------------------------------------

RSpec.shared_examples "tag_relationship search" do |factory_name, model_class|
  include_context "as admin"
  include_context "with tag categories"

  describe ".search" do
    # -------------------------------------------------------------------------
    # name_matches
    # -------------------------------------------------------------------------
    describe "name_matches" do
      let!(:matching)    { create(factory_name, antecedent_name: "searchable_ant", consequent_name: "searchable_con") }
      let!(:nonmatching) { create(factory_name) }

      it "returns records where antecedent_name matches the wildcard" do
        results = model_class.search(name_matches: "searchable_ant*")
        expect(results).to include(matching)
        expect(results).not_to include(nonmatching)
      end

      it "returns records where consequent_name matches the wildcard" do
        results = model_class.search(name_matches: "searchable_con*")
        expect(results).to include(matching)
        expect(results).not_to include(nonmatching)
      end

      it "returns all records when name_matches is absent" do
        results = model_class.search({})
        expect(results).to include(matching, nonmatching)
      end
    end

    # -------------------------------------------------------------------------
    # antecedent_name
    # -------------------------------------------------------------------------
    describe "antecedent_name" do
      let!(:target) { create(factory_name, antecedent_name: "specific_antecedent") }
      let!(:other)  { create(factory_name) }

      it "filters by exact antecedent_name" do
        results = model_class.search(antecedent_name: "specific_antecedent")
        expect(results).to include(target)
        expect(results).not_to include(other)
      end

      it "accepts a comma-separated list of antecedent names" do
        second_target = create(factory_name, antecedent_name: "second_antecedent")
        results = model_class.search(antecedent_name: "specific_antecedent,second_antecedent")
        expect(results).to include(target, second_target)
        expect(results).not_to include(other)
      end
    end

    # -------------------------------------------------------------------------
    # consequent_name
    # -------------------------------------------------------------------------
    describe "consequent_name" do
      let!(:target) { create(factory_name, consequent_name: "specific_consequent") }
      let!(:other)  { create(factory_name) }

      it "filters by exact consequent_name" do
        results = model_class.search(consequent_name: "specific_consequent")
        expect(results).to include(target)
        expect(results).not_to include(other)
      end
    end

    # -------------------------------------------------------------------------
    # status
    # -------------------------------------------------------------------------
    describe "status" do
      let!(:pending_record) { create(factory_name) }
      let!(:active_record)  { create(factory_name).tap { |r| r.update_columns(status: "active") } }
      let!(:deleted_record) { create(factory_name).tap { |r| r.update_columns(status: "deleted") } }

      it "filters by exact status value" do
        results = model_class.search(status: "pending")
        expect(results).to include(pending_record)
        expect(results).not_to include(active_record, deleted_record)
      end

      it "maps 'approved' to active, processing, and queued" do
        results = model_class.search(status: "approved")
        expect(results).to include(active_record)
        expect(results).not_to include(pending_record, deleted_record)
      end
    end

    # -------------------------------------------------------------------------
    # antecedent_tag_category
    # -------------------------------------------------------------------------
    describe "antecedent_tag_category" do
      let(:artist_tag)  { create(:artist_tag) }
      let(:general_tag) { create(:tag) }
      let!(:artist_rel) do
        create(factory_name, antecedent_name: artist_tag.name,
                             consequent_name: "con_for_artist_#{SecureRandom.hex(4)}")
      end
      let!(:general_rel) do
        create(factory_name, antecedent_name: general_tag.name,
                             consequent_name: "con_for_general_#{SecureRandom.hex(4)}")
      end

      it "filters by antecedent tag category" do
        results = model_class.search(antecedent_tag_category: artist_tag_category.to_s)
        expect(results).to include(artist_rel)
        expect(results).not_to include(general_rel)
      end
    end

    # -------------------------------------------------------------------------
    # consequent_tag_category
    # -------------------------------------------------------------------------
    describe "consequent_tag_category" do
      let(:copyright_tag) { create(:copyright_tag) }
      let(:general_tag)   { create(:tag) }
      let!(:copyright_rel) do
        create(factory_name, antecedent_name: "ant_for_copy_#{SecureRandom.hex(4)}",
                             consequent_name: copyright_tag.name)
      end
      let!(:general_rel) do
        create(factory_name, antecedent_name: "ant_for_gen_#{SecureRandom.hex(4)}",
                             consequent_name: general_tag.name)
      end

      it "filters by consequent tag category" do
        results = model_class.search(consequent_tag_category: copyright_tag_category.to_s)
        expect(results).to include(copyright_rel)
        expect(results).not_to include(general_rel)
      end
    end

    # -------------------------------------------------------------------------
    # creator filter
    # -------------------------------------------------------------------------
    describe "creator filter" do
      let(:other_admin)       { create(:admin_user) }
      let!(:own_record)       { create(factory_name) }
      let!(:other_record)     { create(factory_name).tap { |r| r.update_columns(creator_id: other_admin.id) } }

      it "filters by creator_id" do
        creator = CurrentUser.user
        results = model_class.search(creator_id: creator.id)
        expect(results).to include(own_record)
        expect(results).not_to include(other_record)
      end

      it "filters by creator_name" do
        creator = CurrentUser.user
        results = model_class.search(creator_name: creator.name)
        expect(results).to include(own_record)
        expect(results).not_to include(other_record)
      end
    end

    # -------------------------------------------------------------------------
    # approver filter
    # -------------------------------------------------------------------------
    describe "approver filter" do
      let(:approver)           { create(:admin_user) }
      let!(:approved_record)   { create(factory_name).tap { |r| r.update_columns(approver_id: approver.id) } }
      let!(:unapproved_record) { create(factory_name) }

      it "filters by approver_id" do
        results = model_class.search(approver_id: approver.id)
        expect(results).to include(approved_record)
        expect(results).not_to include(unapproved_record)
      end

      it "filters by approver_name" do
        results = model_class.search(approver_name: approver.name)
        expect(results).to include(approved_record)
        expect(results).not_to include(unapproved_record)
      end
    end

    # -------------------------------------------------------------------------
    # order
    # -------------------------------------------------------------------------
    describe "order" do
      let!(:older_record) { create(factory_name) }
      let!(:newer_record) { create(factory_name) }

      before do
        older_record.update_columns(created_at: 2.hours.ago, updated_at: 2.hours.ago)
      end

      it "orders by created_at descending when order: 'created_at'" do
        ids = model_class.search(order: "created_at").ids
        expect(ids.index(newer_record.id)).to be < ids.index(older_record.id)
      end

      it "orders by updated_at descending when order: 'updated_at'" do
        ids = model_class.search(order: "updated_at").ids
        expect(ids.index(newer_record.id)).to be < ids.index(older_record.id)
      end

      it "orders alphabetically by antecedent_name when order: 'name'" do
        older_record.update_columns(antecedent_name: "aaa_antecedent")
        newer_record.update_columns(antecedent_name: "zzz_antecedent")
        ids = model_class.search(order: "name").ids
        expect(ids.index(older_record.id)).to be < ids.index(newer_record.id)
      end

      it "uses pending_first ordering by default" do
        pending_rec = create(factory_name)
        active_rec  = create(factory_name).tap { |r| r.update_columns(status: "active") }
        ids = model_class.search({}).ids
        # pending (array_position index 2) sorts before active (index 3)
        expect(ids.index(pending_rec.id)).to be < ids.index(active_rec.id)
      end
    end
  end
end

# ---------------------------------------------------------------------------
# 7. Message Methods
# ---------------------------------------------------------------------------

RSpec.shared_examples "tag_relationship message methods" do |factory_name, _model_class|
  include_context "as admin"

  describe "message methods" do
    let(:approver) { create(:admin_user) }
    let(:rejector) { create(:admin_user) }
    let(:record)   { create(factory_name) }

    describe "#relationship" do
      it "returns the human-readable class name" do
        expected = record.class.name.underscore.tr("_", " ")
        expect(record.relationship).to eq(expected)
      end
    end

    describe "#approval_message" do
      it "includes the antecedent name, consequent name, and approver name" do
        msg = record.approval_message(approver)
        expect(msg).to include(record.antecedent_name)
        expect(msg).to include(record.consequent_name)
        expect(msg).to include(approver.name)
      end
    end

    describe "#failure_message" do
      it "includes the antecedent name, consequent name, and error reason" do
        error = StandardError.new("job failed unexpectedly")
        msg   = record.failure_message(error)
        expect(msg).to include(record.antecedent_name)
        expect(msg).to include(record.consequent_name)
        expect(msg).to include("job failed unexpectedly")
      end
    end

    describe "#reject_message" do
      it "includes the antecedent name, consequent name, and rejector name" do
        msg = record.reject_message(rejector)
        expect(msg).to include(record.antecedent_name)
        expect(msg).to include(record.consequent_name)
        expect(msg).to include(rejector.name)
      end
    end

    describe "#retirement_message" do
      it "includes the antecedent name and consequent name" do
        msg = record.retirement_message
        expect(msg).to include(record.antecedent_name)
        expect(msg).to include(record.consequent_name)
      end
    end

    describe "#forum_link" do
      it "returns nil when no forum post is associated" do
        expect(record.forum_link).to be_nil
      end

      it "returns a formatted link when a forum post is present" do
        forum_topic = create(:forum_topic)
        forum_post  = forum_topic.posts.first
        record.forum_post = forum_post
        expect(record.forum_link).to eq("(forum ##{forum_post.id})")
      end
    end
  end
end
