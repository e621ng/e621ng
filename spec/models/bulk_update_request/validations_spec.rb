# frozen_string_literal: true

require "rails_helper"

RSpec.describe BulkUpdateRequest do
  include_context "as admin"

  def build_bur(overrides = {})
    build(:bulk_update_request, **overrides)
  end

  # ---------------------------------------------------------------------------
  # Presence
  # ---------------------------------------------------------------------------
  describe "presence validations" do
    it "is invalid without a user" do
      # initialize_attributes (before_validation: create) sets user_id from CurrentUser,
      # so we test on a persisted record where the callback does not run.
      bur = create(:bulk_update_request)
      bur.user_id = nil
      expect(bur).not_to be_valid
      expect(bur.errors[:user]).to be_present
    end

    it "is invalid without a script" do
      bur = build_bur(script: "")
      expect(bur).not_to be_valid
      expect(bur.errors[:script]).to be_present
    end

    it "is invalid without a title when no forum_topic_id" do
      bur = build_bur(title: nil, forum_topic_id: nil)
      expect(bur).not_to be_valid
      expect(bur.errors[:title]).to be_present
    end

    it "is valid without a title when forum_topic_id is provided" do
      topic = create(:forum_topic)
      bur = build_bur(title: nil, forum_topic_id: topic.id)
      expect(bur).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # Status inclusion
  # ---------------------------------------------------------------------------
  describe "status inclusion" do
    %w[pending approved rejected].each do |valid_status|
      it "is valid with status '#{valid_status}'" do
        bur = build_bur
        bur.status = valid_status
        bur.validate
        expect(bur.errors[:status]).to be_blank
      end
    end

    it "is invalid with an unrecognized status" do
      # initialize_attributes (before_validation: create) always sets status to "pending",
      # so we test on a persisted record where the callback does not run.
      bur = create(:bulk_update_request)
      bur.status = "bogus"
      expect(bur).not_to be_valid
      expect(bur.errors[:status]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # script_formatted_correctly
  # ---------------------------------------------------------------------------
  describe "#script_formatted_correctly" do
    it "is invalid when the script contains an unparseable line" do
      bur = build_bur(script: "this is not valid syntax")
      expect(bur).not_to be_valid
      expect(bur.errors[:base].join).to match(/Unparseable line/)
    end

    {
      "create alias"       => "create alias a -> b",
      "aliasing"           => "aliasing a -> b",
      "alias"              => "alias a -> b",
      "create implication" => "create implication a -> b",
      "implicating"        => "implicating a -> b",
      "implicate"          => "implicate a -> b",
      "imply"              => "imply a -> b",
      "remove alias"       => "remove alias a -> b",
      "unalias"            => "unalias a -> b",
      "remove implication" => "remove implication a -> b",
      "unimplicate"        => "unimplicate a -> b",
      "nuke tag"           => "nuke tag a",
      "nuke"               => "nuke a",
      "mass update"        => "mass update a -> b",
      "update"             => "update a -> b",
      "change"             => "change a -> b",
      "category"           => "category a -> general",
    }.each do |prefix, script_line|
      it "is parseable with '#{prefix}' prefix" do
        bur = build_bur(script: script_line)
        bur.validate
        expect(bur.errors[:base].join).not_to match(/Unparseable line/)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # forum_topic_id_not_invalid
  # ---------------------------------------------------------------------------
  describe "#forum_topic_id_not_invalid" do
    it "is invalid when forum_topic_id references a non-existent topic" do
      bur = build_bur(forum_topic_id: 999_999_999)
      expect(bur).not_to be_valid
      expect(bur.errors[:base]).to include("Forum topic ID is invalid")
    end
  end

  # ---------------------------------------------------------------------------
  # validate_script (on: :create)
  # ---------------------------------------------------------------------------
  describe "#validate_script on create" do
    it "is invalid when the alias would alias a tag to itself" do
      bur = build_bur(script: "alias self_tag -> self_tag")
      expect(bur).not_to be_valid
      expect(bur.errors[:base].join).to match(/Cannot alias or implicate a tag to itself/)
    end

    it "is valid when an alias already exists in duplicate_relevant scope (annotated, not an error)" do
      create(:tag_alias, antecedent_name: "dup_valid_ant", consequent_name: "dup_valid_con")
      bur = build_bur(script: "alias dup_valid_ant -> dup_valid_con")
      expect(bur).to be_valid
    end

    it "annotates the script when the alias would cause transitive relationships (but does not add an error)" do
      # When an existing alias X -> start_trans exists, creating start_trans -> mid_trans
      # would form a chain. validate_alias annotates the token but does NOT add an error.
      create(:active_tag_alias, antecedent_name: "chain_source", consequent_name: "chain_ant")
      bur = create(:bulk_update_request, script: "alias chain_ant -> chain_con")
      expect(bur.errors[:base]).to be_empty
      expect(bur.script).to match(/blocking transitive relationships/)
    end

    it "allows an admin to create a BUR with more than 25 entries" do
      lines = 26.times.map { |n| "alias many_ant_#{n} -> many_con_#{n}" }.join("\n")
      bur = build_bur(script: lines)
      expect(bur).to be_valid
    end

    it "rejects a non-admin creating a BUR with more than 25 entries" do
      member = create(:user)
      CurrentUser.user = member

      lines = 26.times.map { |n| "alias nonmany_ant_#{n} -> nonmany_con_#{n}" }.join("\n")
      bur = build_bur(script: lines, user: member)
      expect(bur).not_to be_valid
      expect(bur.errors[:base]).to include("Cannot create BUR with more than 25 entries")
    end

    # FIXME: nuke_tag restriction to admin — BulkUpdateRequestImporter adds the error
    # but only via validate_annotate which is called from validate_script. Testing this
    # as a member requires CurrentUser to be a non-admin AND validate_alias/validate_implication
    # to not call creator.can_suggest_tag_with_reason (which requires admin). Needs further
    # investigation of whether a member user can even pass the factory-level TagAlias validation.
    # it "rejects a non-admin trying to nuke a tag" do
    #   member = create(:user)
    #   CurrentUser.user = member
    #   bur = build_bur(script: "nuke tag some_tag", user: member)
    #   expect(bur).not_to be_valid
    #   expect(bur.errors[:base]).to include("Only admins can nuke tags")
    # end
  end

  # ---------------------------------------------------------------------------
  # check_validate_script (on: :update)
  # ---------------------------------------------------------------------------
  describe "#check_validate_script on update" do
    it "does not run validate_script on update when should_validate is false" do
      bur = create(:bulk_update_request)
      # Use a parseable-but-semantically-invalid script: aliasing a tag to itself
      # passes tokenization but would fail validate_script (which checks for alias-to-self).
      # With should_validate false, validate_script is skipped so the record is valid.
      bur.should_validate = false
      bur.script = "alias check_skip_ant -> check_skip_ant"
      expect(bur).to be_valid
    end

    it "re-validates the script when should_validate is true and adds errors for an invalid script" do
      bur = create(:bulk_update_request)
      bur.script = "alias revalidate_ant -> revalidate_ant"
      bur.should_validate = true
      expect(bur).not_to be_valid
      expect(bur.errors[:base].join).to match(/Cannot alias or implicate a tag to itself/)
    end
  end

  # ---------------------------------------------------------------------------
  # reason length (on: :create, unless: :skip_forum)
  # ---------------------------------------------------------------------------
  describe "reason minimum length" do
    it "is invalid on create with a reason shorter than 5 characters when skip_forum is false" do
      topic = create(:forum_topic)
      bur = build_bur(forum_topic_id: topic.id, skip_forum: false, reason: "hi")
      expect(bur).not_to be_valid
      expect(bur.errors[:reason]).to be_present
    end

    it "is valid on create without a reason when skip_forum is true" do
      bur = build_bur(skip_forum: true, reason: nil)
      expect(bur).to be_valid
    end
  end
end
