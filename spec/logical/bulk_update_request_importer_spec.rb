# frozen_string_literal: true

require "rails_helper"

RSpec.describe BulkUpdateRequestImporter do
  include_context "as admin"

  let(:approver) { create(:admin_user) }

  def importer(script, forum_id = nil)
    BulkUpdateRequestImporter.new(script, forum_id, CurrentUser.id, CurrentUser.ip_addr)
  end

  # ---------------------------------------------------------------------------
  # .tokenize
  # ---------------------------------------------------------------------------
  describe ".tokenize" do
    # create_alias prefixes
    it "recognizes 'alias ant -> con'" do
      expect(described_class.tokenize("alias ant -> con").first[0]).to eq(:create_alias)
    end

    it "recognizes 'create alias ant -> con'" do
      expect(described_class.tokenize("create alias ant -> con").first[0]).to eq(:create_alias)
    end

    it "recognizes 'aliasing ant -> con'" do
      expect(described_class.tokenize("aliasing ant -> con").first[0]).to eq(:create_alias)
    end

    # create_implication prefixes
    it "recognizes 'implicate ant -> con'" do
      expect(described_class.tokenize("implicate ant -> con").first[0]).to eq(:create_implication)
    end

    it "recognizes 'create implication ant -> con'" do
      expect(described_class.tokenize("create implication ant -> con").first[0]).to eq(:create_implication)
    end

    it "recognizes 'implicating ant -> con'" do
      expect(described_class.tokenize("implicating ant -> con").first[0]).to eq(:create_implication)
    end

    it "recognizes 'imply ant -> con'" do
      expect(described_class.tokenize("imply ant -> con").first[0]).to eq(:create_implication)
    end

    # remove_alias prefixes
    it "recognizes 'unalias ant -> con'" do
      expect(described_class.tokenize("unalias ant -> con").first[0]).to eq(:remove_alias)
    end

    it "recognizes 'remove alias ant -> con'" do
      expect(described_class.tokenize("remove alias ant -> con").first[0]).to eq(:remove_alias)
    end

    it "recognizes 'unaliasing ant -> con'" do
      expect(described_class.tokenize("unaliasing ant -> con").first[0]).to eq(:remove_alias)
    end

    # remove_implication prefixes
    it "recognizes 'unimplicate ant -> con'" do
      expect(described_class.tokenize("unimplicate ant -> con").first[0]).to eq(:remove_implication)
    end

    it "recognizes 'remove implication ant -> con'" do
      expect(described_class.tokenize("remove implication ant -> con").first[0]).to eq(:remove_implication)
    end

    it "recognizes 'unimply ant -> con'" do
      expect(described_class.tokenize("unimply ant -> con").first[0]).to eq(:remove_implication)
    end

    # mass_update prefixes
    it "recognizes 'update ant -> con'" do
      expect(described_class.tokenize("update ant -> con").first[0]).to eq(:mass_update)
    end

    it "recognizes 'mass update ant -> con'" do
      expect(described_class.tokenize("mass update ant -> con").first[0]).to eq(:mass_update)
    end

    it "recognizes 'change ant -> con'" do
      expect(described_class.tokenize("change ant -> con").first[0]).to eq(:mass_update)
    end

    # nuke_tag prefixes
    it "recognizes 'nuke some_tag'" do
      expect(described_class.tokenize("nuke some_tag").first[0]).to eq(:nuke_tag)
    end

    it "recognizes 'nuke tag some_tag'" do
      expect(described_class.tokenize("nuke tag some_tag").first[0]).to eq(:nuke_tag)
    end

    # change_category
    it "recognizes 'category some_tag -> general'" do
      expect(described_class.tokenize("category some_tag -> general").first[0]).to eq(:change_category)
    end

    # token fields
    it "captures antecedent as token[1]" do
      expect(described_class.tokenize("alias ant -> con").first[1]).to eq("ant")
    end

    it "captures consequent as token[2]" do
      expect(described_class.tokenize("alias ant -> con").first[2]).to eq("con")
    end

    it "captures an inline comment in token[3]" do
      token = described_class.tokenize("alias ant -> con # my comment").first
      expect(token[3]).to include("my comment")
    end

    it "sets token[3] to nil when no comment is present" do
      expect(described_class.tokenize("alias ant -> con").first[3]).to be_nil
    end

    # blank line handling
    it "returns an empty array for blank input" do
      expect(described_class.tokenize("")).to eq([])
    end

    it "filters out blank lines and returns only valid tokens" do
      tokens = described_class.tokenize("\nalias ant -> con\n\nalias ant2 -> con2\n")
      expect(tokens.size).to eq(2)
    end

    # case insensitivity
    it "parses directives case-insensitively" do
      expect(described_class.tokenize("ALIAS ant -> con").first[0]).to eq(:create_alias)
    end

    # error
    it "raises BulkUpdateRequestImporter::Error on an unparseable line" do
      expect { described_class.tokenize("this is garbage") }
        .to raise_error(BulkUpdateRequestImporter::Error, /Unparseable line/)
    end
  end

  # ---------------------------------------------------------------------------
  # .untokenize
  # ---------------------------------------------------------------------------
  describe ".untokenize" do
    it "produces 'alias ant -> con' for :create_alias" do
      expect(described_class.untokenize([[:create_alias, "ant", "con", nil]])).to eq(["alias ant -> con"])
    end

    it "produces 'implicate ant -> con' for :create_implication" do
      expect(described_class.untokenize([[:create_implication, "ant", "con", nil]])).to eq(["implicate ant -> con"])
    end

    it "produces 'unalias ant -> con' for :remove_alias" do
      expect(described_class.untokenize([[:remove_alias, "ant", "con", nil]])).to eq(["unalias ant -> con"])
    end

    it "appends '# missing' for :remove_alias when token[3] is false" do
      expect(described_class.untokenize([[:remove_alias, "ant", "con", false]])).to eq(["unalias ant -> con # missing"])
    end

    it "produces 'unimplicate ant -> con' for :remove_implication" do
      expect(described_class.untokenize([[:remove_implication, "ant", "con", nil]])).to eq(["unimplicate ant -> con"])
    end

    it "appends '# missing' for :remove_implication when token[3] is false" do
      expect(described_class.untokenize([[:remove_implication, "ant", "con", false]])).to eq(["unimplicate ant -> con # missing"])
    end

    it "produces 'update ant -> con' for :mass_update" do
      expect(described_class.untokenize([[:mass_update, "ant", "con", nil]])).to eq(["update ant -> con"])
    end

    it "appends '# missing' for :mass_update when token[3] is false" do
      expect(described_class.untokenize([[:mass_update, "ant", "con", false]])).to eq(["update ant -> con # missing"])
    end

    it "produces 'nuke tag name' for :nuke_tag" do
      expect(described_class.untokenize([[:nuke_tag, "some_tag", nil, nil]])).to eq(["nuke tag some_tag"])
    end

    it "appends '# missing' for :nuke_tag when token[3] is false" do
      expect(described_class.untokenize([[:nuke_tag, "some_tag", nil, false]])).to eq(["nuke tag some_tag # missing"])
    end

    it "produces 'category tag -> cat' for :change_category" do
      expect(described_class.untokenize([[:change_category, "some_tag", "general", nil]])).to eq(["category some_tag -> general"])
    end

    it "appends '# missing' for :change_category when token[3] is false" do
      expect(described_class.untokenize([[:change_category, "some_tag", "general", false]])).to eq(["category some_tag -> general # missing"])
    end

    it "raises BulkUpdateRequestImporter::Error for an unknown token type" do
      expect { described_class.untokenize([[:unknown_type, "a", "b", nil]]) }
        .to raise_error(BulkUpdateRequestImporter::Error, /Unknown token to reverse/)
    end
  end

  # ---------------------------------------------------------------------------
  # #validate_alias
  # ---------------------------------------------------------------------------
  describe "#validate_alias" do
    def token(ant, con)
      [:create_alias, ant, con, nil]
    end

    context "when no existing alias or implication conflicts exist" do
      it "returns [nil, nil]" do
        result = importer("alias va_clean_ant -> va_clean_con").validate_alias(token("va_clean_ant", "va_clean_con"))
        expect(result).to eq([nil, nil])
      end
    end

    context "when a duplicate_relevant alias already exists (no transitives)" do
      let!(:existing) do
        ta = create(:tag_alias, antecedent_name: "va_dup_ant", consequent_name: "va_dup_con")
        ta.update_columns(status: "active")
        ta
      end

      it "returns nil error and a warning naming the duplicate alias" do
        result = importer("alias va_dup_ant -> va_dup_con").validate_alias(token("va_dup_ant", "va_dup_con"))
        expect(result[0]).to be_nil
        expect(result[1]).to include("duplicate of alias ##{existing.id}")
      end
    end

    context "when a duplicate_relevant alias exists and has transitive relationships" do
      # Create the blocker first (pending), then update to active so the
      # subsequent creation of existing does not trigger absence_of_transitive_relation.
      before do
        ta = create(:tag_alias, antecedent_name: "va_trans_blocker", consequent_name: "va_trans_dup_ant")
        ta.update_columns(status: "active")
      end

      let!(:existing) do
        ta = create(:tag_alias, antecedent_name: "va_trans_dup_ant", consequent_name: "va_trans_dup_con")
        ta.update_columns(status: "active")
        ta
      end

      it "returns nil error and a warning about the duplicate alias with blocking transitives" do
        result = importer("alias va_trans_dup_ant -> va_trans_dup_con").validate_alias(token("va_trans_dup_ant", "va_trans_dup_con"))
        expect(result[0]).to be_nil
        expect(result[1]).to include("duplicate of alias ##{existing.id}")
        expect(result[1]).to include("has blocking transitive relationships")
      end
    end

    context "when a new alias fails validation" do
      # antecedent_and_consequent_are_different fires for same -> same
      it "returns an error message and nil warning" do
        result = importer("alias va_same -> va_same").validate_alias(token("va_same", "va_same"))
        expect(result[0]).to include("Error:")
        expect(result[1]).to be_nil
      end
    end

    context "when a new alias would have transitive relationships" do
      # blocker "other -> va_new_trans_ant" causes has_transitives to return true
      # for a new alias "va_new_trans_ant -> va_new_trans_con"
      before do
        ta = create(:tag_alias, antecedent_name: "va_new_trans_other", consequent_name: "va_new_trans_ant")
        ta.update_columns(status: "active")
      end

      it "returns nil error and a warning about transitive relationships" do
        result = importer("alias va_new_trans_ant -> va_new_trans_con").validate_alias(token("va_new_trans_ant", "va_new_trans_con"))
        expect(result[0]).to be_nil
        expect(result[1]).to include("has blocking transitive relationships")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #validate_implication
  # ---------------------------------------------------------------------------
  describe "#validate_implication" do
    def token(ant, con)
      [:create_implication, ant, con, nil]
    end

    context "when no existing implication conflicts exist" do
      it "returns [nil, nil]" do
        result = importer("implicate vi_clean_ant -> vi_clean_con").validate_implication(token("vi_clean_ant", "vi_clean_con"))
        expect(result).to eq([nil, nil])
      end
    end

    context "when a duplicate_relevant implication already exists" do
      let!(:existing) do
        ti = create(:tag_implication, antecedent_name: "vi_dup_ant", consequent_name: "vi_dup_con")
        ti.update_columns(status: "active")
        ti
      end

      it "returns nil error and a warning naming the duplicate implication" do
        result = importer("implicate vi_dup_ant -> vi_dup_con").validate_implication(token("vi_dup_ant", "vi_dup_con"))
        expect(result[0]).to be_nil
        expect(result[1]).to include("duplicate of implication ##{existing.id}")
      end
    end

    context "when implication validation fails (antecedent == consequent)" do
      it "returns an error message and nil warning" do
        result = importer("implicate vi_same -> vi_same").validate_implication(token("vi_same", "vi_same"))
        expect(result[0]).to include("Error:")
        expect(result[1]).to be_nil
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #validate! (validate_annotate)
  # ---------------------------------------------------------------------------
  describe "#validate!" do
    let(:member) { create(:user) }

    it "returns a two-element array [errors, script_string]" do
      result = importer("alias vann_ant -> vann_con").validate!(CurrentUser.user)
      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
    end

    describe "create_alias token" do
      it "returns empty errors for a valid alias" do
        errors, _script = importer("alias vld_ca_ant -> vld_ca_con").validate!(CurrentUser.user)
        expect(errors).to be_empty
      end

      it "includes the alias line in the returned script" do
        _errors, script = importer("alias vld_ca_ant -> vld_ca_con").validate!(CurrentUser.user)
        expect(script).to include("vld_ca_ant")
      end

      it "returns errors for an invalid alias" do
        errors, _script = importer("alias vld_ca_same -> vld_ca_same").validate!(CurrentUser.user)
        expect(errors).not_to be_empty
      end
    end

    describe "create_implication token" do
      it "returns empty errors for a valid implication" do
        errors, _script = importer("implicate vld_ci_ant -> vld_ci_con").validate!(CurrentUser.user)
        expect(errors).to be_empty
      end
    end

    describe "remove_alias token" do
      context "when the alias exists" do
        before do
          ta = create(:tag_alias, antecedent_name: "vann_ra_ant", consequent_name: "vann_ra_con")
          ta.update_columns(status: "active")
        end

        it "does not append '# missing' to the script" do
          _errors, script = importer("unalias vann_ra_ant -> vann_ra_con").validate!(CurrentUser.user)
          expect(script).not_to include("# missing")
        end
      end

      context "when the alias is absent" do
        it "appends '# missing' to the script" do
          _errors, script = importer("unalias vann_absent_ant -> vann_absent_con").validate!(CurrentUser.user)
          expect(script).to include("# missing")
        end
      end
    end

    describe "remove_implication token" do
      context "when the implication exists" do
        before do
          ti = create(:tag_implication, antecedent_name: "vann_ri_ant", consequent_name: "vann_ri_con")
          ti.update_columns(status: "active")
        end

        it "does not append '# missing' to the script" do
          _errors, script = importer("unimplicate vann_ri_ant -> vann_ri_con").validate!(CurrentUser.user)
          expect(script).not_to include("# missing")
        end
      end

      context "when the implication is absent" do
        it "appends '# missing' to the script" do
          _errors, script = importer("unimplicate vann_ri_absent_ant -> vann_ri_absent_con").validate!(CurrentUser.user)
          expect(script).to include("# missing")
        end
      end
    end

    describe "mass_update token" do
      context "when the source tag exists" do
        before { create(:tag, name: "vann_mu_src_tag") }

        it "does not append '# missing' to the script" do
          _errors, script = importer("update vann_mu_src_tag -> vann_mu_dst_tag").validate!(CurrentUser.user)
          expect(script).not_to include("# missing")
        end
      end

      context "when the source tag is absent" do
        it "appends '# missing' to the script" do
          _errors, script = importer("update vann_mu_absent_tag -> vann_mu_dst_tag").validate!(CurrentUser.user)
          expect(script).to include("# missing")
        end
      end
    end

    describe "change_category token" do
      context "when the tag exists" do
        before { create(:tag, name: "vann_cc_tag") }

        it "does not append '# missing' to the script" do
          _errors, script = importer("category vann_cc_tag -> general").validate!(CurrentUser.user)
          expect(script).not_to include("# missing")
        end
      end

      context "when the tag is absent" do
        it "appends '# missing' to the script" do
          _errors, script = importer("category vann_cc_absent_tag -> general").validate!(CurrentUser.user)
          expect(script).to include("# missing")
        end
      end
    end

    describe "nuke_tag token" do
      it "does not add an admin error when the user is an admin" do
        errors, _script = importer("nuke vann_nuke_tag").validate!(CurrentUser.user)
        expect(errors).not_to include("Only admins can nuke tags")
      end

      it "adds an 'Only admins can nuke tags' error when the user is not an admin" do
        errors, _script = importer("nuke vann_nuke_tag").validate!(member)
        expect(errors).to include("Only admins can nuke tags")
      end
    end

    describe "entry count limit" do
      let(:big_script) { (1..26).map { |i| "alias vann_big_ant_#{i} -> vann_big_con_#{i}" }.join("\n") }

      it "adds a 'Cannot create BUR with more than 25 entries' error for non-admins" do
        errors, _script = importer(big_script).validate!(member)
        expect(errors).to include("Cannot create BUR with more than 25 entries")
      end

      it "does not add that error for admins" do
        errors, _script = importer(big_script).validate!(CurrentUser.user)
        expect(errors).not_to include("Cannot create BUR with more than 25 entries")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #estimate_update_count
  # ---------------------------------------------------------------------------
  describe "#estimate_update_count" do
    before { create(:tag, name: "euc_tag").tap { |t| t.update_columns(post_count: 42) } }

    it "returns the tag post_count for mass_update lines" do
      expect(importer("update euc_tag -> euc_new_tag").estimate_update_count).to eq(42)
    end

    it "returns the tag post_count for nuke_tag lines" do
      expect(importer("nuke euc_tag").estimate_update_count).to eq(42)
    end

    it "returns the tag post_count for change_category lines" do
      expect(importer("category euc_tag -> general").estimate_update_count).to eq(42)
    end

    it "returns 0 for a missing tag in mass_update" do
      expect(importer("update euc_absent_tag -> euc_dst").estimate_update_count).to eq(0)
    end

    it "returns 0 for remove_alias lines" do
      expect(importer("unalias euc_ant -> euc_con").estimate_update_count).to eq(0)
    end

    it "returns 0 for remove_implication lines" do
      expect(importer("unimplicate euc_ant -> euc_con").estimate_update_count).to eq(0)
    end

    it "returns a non-negative integer for create_alias lines" do
      expect(importer("alias euc_tag -> euc_alias_dst").estimate_update_count).to be >= 0
    end

    it "returns a non-negative integer for create_implication lines" do
      expect(importer("implicate euc_tag -> euc_impl_dst").estimate_update_count).to be >= 0
    end

    it "sums contributions across multiple lines" do
      create(:tag, name: "euc_tag2").tap { |t| t.update_columns(post_count: 10) }
      count = importer("update euc_tag -> euc_x\nnuke euc_tag2").estimate_update_count
      expect(count).to eq(52)
    end
  end

  # ---------------------------------------------------------------------------
  # #process!
  # ---------------------------------------------------------------------------
  describe "#process!" do
    describe "create_alias" do
      it "creates a new TagAlias record" do
        expect { importer("alias proc_ca_ant -> proc_ca_con").process!(approver) }
          .to change { TagAlias.where(antecedent_name: "proc_ca_ant", consequent_name: "proc_ca_con").count }.by(1)
      end

      it "enqueues a TagAliasJob" do
        expect { importer("alias proc_ca_ant -> proc_ca_con").process!(approver) }
          .to have_enqueued_job(TagAliasJob)
      end

      context "when a pending alias already exists for the pair" do
        before { create(:tag_alias, antecedent_name: "proc_ca_reuse_ant", consequent_name: "proc_ca_reuse_con", status: "pending") }

        it "does not create a second TagAlias" do
          expect { importer("alias proc_ca_reuse_ant -> proc_ca_reuse_con").process!(approver) }
            .not_to change(TagAlias, :count)
        end

        it "enqueues a TagAliasJob for the reused alias" do
          expect { importer("alias proc_ca_reuse_ant -> proc_ca_reuse_con").process!(approver) }
            .to have_enqueued_job(TagAliasJob)
        end
      end

      context "when an active alias already exists for the pair" do
        before do
          ta = create(:tag_alias, antecedent_name: "proc_ca_skip_ant", consequent_name: "proc_ca_skip_con")
          ta.update_columns(status: "active")
        end

        it "does not raise an error" do
          expect { importer("alias proc_ca_skip_ant -> proc_ca_skip_con").process!(approver) }
            .not_to raise_error
        end

        it "does not create another TagAlias" do
          expect { importer("alias proc_ca_skip_ant -> proc_ca_skip_con").process!(approver) }
            .not_to change(TagAlias, :count)
        end
      end

      context "when the alias has transitive relationships" do
        before do
          ta = create(:tag_alias, antecedent_name: "proc_ca_trans_other", consequent_name: "proc_ca_trans_ant")
          ta.update_columns(status: "active")
        end

        it "raises BulkUpdateRequestImporter::Error mentioning transitive relationships" do
          expect { importer("alias proc_ca_trans_ant -> proc_ca_trans_con").process!(approver) }
            .to raise_error(BulkUpdateRequestImporter::Error, /transitive/)
        end
      end
    end

    describe "create_implication" do
      it "creates a new TagImplication record" do
        expect { importer("implicate proc_ci_ant -> proc_ci_con").process!(approver) }
          .to change { TagImplication.where(antecedent_name: "proc_ci_ant", consequent_name: "proc_ci_con").count }.by(1)
      end

      it "enqueues a TagImplicationJob" do
        expect { importer("implicate proc_ci_ant -> proc_ci_con").process!(approver) }
          .to have_enqueued_job(TagImplicationJob)
      end

      context "when a pending implication already exists for the pair" do
        before { create(:tag_implication, antecedent_name: "proc_ci_reuse_ant", consequent_name: "proc_ci_reuse_con", status: "pending") }

        it "does not create a second TagImplication" do
          expect { importer("implicate proc_ci_reuse_ant -> proc_ci_reuse_con").process!(approver) }
            .not_to change(TagImplication, :count)
        end
      end

      context "when an active implication already exists for the pair" do
        before do
          ti = create(:tag_implication, antecedent_name: "proc_ci_skip_ant", consequent_name: "proc_ci_skip_con")
          ti.update_columns(status: "active")
        end

        it "does not raise an error" do
          expect { importer("implicate proc_ci_skip_ant -> proc_ci_skip_con").process!(approver) }
            .not_to raise_error
        end
      end
    end

    describe "remove_alias" do
      context "when an active alias exists" do
        let!(:existing) do
          ta = create(:tag_alias, antecedent_name: "proc_ra_ant", consequent_name: "proc_ra_con")
          ta.update_columns(status: "active")
          ta
        end

        it "sets the alias status to deleted" do
          importer("unalias proc_ra_ant -> proc_ra_con").process!(approver)
          expect(existing.reload.status).to eq("deleted")
        end
      end

      context "when no active alias exists" do
        it "raises BulkUpdateRequestImporter::Error" do
          expect { importer("unalias proc_ra_missing_ant -> proc_ra_missing_con").process!(approver) }
            .to raise_error(BulkUpdateRequestImporter::Error, /Alias for proc_ra_missing_ant not found/)
        end
      end
    end

    describe "remove_implication" do
      context "when an active implication exists" do
        let!(:existing) do
          ti = create(:tag_implication, antecedent_name: "proc_ri_ant", consequent_name: "proc_ri_con")
          ti.update_columns(status: "active")
          ti
        end

        it "sets the implication status to deleted" do
          importer("unimplicate proc_ri_ant -> proc_ri_con").process!(approver)
          expect(existing.reload.status).to eq("deleted")
        end
      end

      context "when no active implication exists" do
        it "raises BulkUpdateRequestImporter::Error" do
          expect { importer("unimplicate proc_ri_missing_ant -> proc_ri_missing_con").process!(approver) }
            .to raise_error(BulkUpdateRequestImporter::Error, /Implication for proc_ri_missing_ant not found/)
        end
      end
    end

    describe "mass_update" do
      it "enqueues a TagBatchJob with the source and destination tag names" do
        expect { importer("update proc_mu_src -> proc_mu_dst").process!(approver) }
          .to have_enqueued_job(TagBatchJob).with("proc_mu_src", "proc_mu_dst", anything, anything)
      end
    end

    describe "nuke_tag" do
      it "enqueues a TagNukeJob with the tag name" do
        expect { importer("nuke proc_nuke_target").process!(approver) }
          .to have_enqueued_job(TagNukeJob).with("proc_nuke_target", anything, anything)
      end
    end

    describe "change_category" do
      context "when the tag exists" do
        let!(:tag) { create(:tag, name: "proc_cc_tag", category: 0) }

        it "updates the tag's category to the specified value" do
          importer("category proc_cc_tag -> director").process!(approver)
          expect(tag.reload.category).to eq(Tag.categories.director)
        end
      end

      context "when the tag does not exist" do
        it "raises BulkUpdateRequestImporter::Error" do
          expect { importer("category proc_cc_missing_tag -> general").process!(approver) }
            .to raise_error(BulkUpdateRequestImporter::Error, /Tag for proc_cc_missing_tag not found/)
        end
      end
    end

    describe "transaction rollback" do
      it "rolls back all changes when a later operation raises an error" do
        # First op creates a TagAlias; second op raises because the alias to remove does not exist.
        script = "alias proc_tx_ant -> proc_tx_con\nunalias proc_tx_missing_ant -> proc_tx_missing_con"
        expect { importer(script).process!(approver) }
          .to raise_error(BulkUpdateRequestImporter::Error)
        expect(TagAlias.where(antecedent_name: "proc_tx_ant", consequent_name: "proc_tx_con")).not_to exist
      end
    end
  end
end
