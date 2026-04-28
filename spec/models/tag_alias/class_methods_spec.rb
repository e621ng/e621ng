# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagAlias do
  include_context "as admin"

  # ---------------------------------------------------------------------------
  # .to_aliased_with_originals
  # ---------------------------------------------------------------------------
  describe ".to_aliased_with_originals" do
    it "maps an aliased name to its consequent" do
      create(:active_tag_alias, antecedent_name: "old_tag", consequent_name: "new_tag")
      expect(TagAlias.to_aliased_with_originals(["old_tag"])).to eq("old_tag" => "new_tag")
    end

    it "maps a non-aliased name to itself" do
      expect(TagAlias.to_aliased_with_originals(["no_alias_tag"])).to eq("no_alias_tag" => "no_alias_tag")
    end

    it "returns an empty hash for empty input" do
      expect(TagAlias.to_aliased_with_originals([])).to eq({})
    end

    it "ignores pending aliases (only active/processing/queued apply)" do
      create(:tag_alias, antecedent_name: "pending_ant", consequent_name: "pending_con")
      result = TagAlias.to_aliased_with_originals(["pending_ant"])
      expect(result).to eq("pending_ant" => "pending_ant")
    end

    it "handles a mix of aliased and non-aliased names" do
      create(:active_tag_alias, antecedent_name: "aliased_tag", consequent_name: "target_tag")
      result = TagAlias.to_aliased_with_originals(%w[aliased_tag unaliased_tag])
      expect(result).to eq("aliased_tag" => "target_tag", "unaliased_tag" => "unaliased_tag")
    end
  end

  # ---------------------------------------------------------------------------
  # .to_aliased
  # ---------------------------------------------------------------------------
  describe ".to_aliased" do
    it "returns the consequent name for an aliased tag" do
      create(:active_tag_alias, antecedent_name: "old_tag", consequent_name: "new_tag")
      result = TagAlias.to_aliased(["old_tag"])
      expect(result).to include("new_tag")
      expect(result).not_to include("old_tag")
    end

    it "passes non-aliased names through unchanged" do
      result = TagAlias.to_aliased(["unaliased_tag"])
      expect(result).to include("unaliased_tag")
    end
  end

  # ---------------------------------------------------------------------------
  # .to_aliased_query
  # ---------------------------------------------------------------------------
  describe ".to_aliased_query" do
    before do
      create(:active_tag_alias, antecedent_name: "old_tag", consequent_name: "new_tag")
    end

    it "replaces an aliased tag in a simple query" do
      expect(TagAlias.to_aliased_query("old_tag")).to eq("new_tag")
    end

    it "preserves the negation prefix" do
      expect(TagAlias.to_aliased_query("-old_tag")).to eq("-new_tag")
    end

    it "preserves the optional prefix" do
      expect(TagAlias.to_aliased_query("~old_tag")).to eq("~new_tag")
    end

    it "normalises -~ to ~- (optional takes precedence over negation)" do
      expect(TagAlias.to_aliased_query("-~old_tag")).to eq("~-new_tag")
    end

    it "leaves unaliased tags unchanged" do
      expect(TagAlias.to_aliased_query("unrelated_tag")).to eq("unrelated_tag")
    end

    it "strips tag-type prefixes before alias lookup" do
      expect(TagAlias.to_aliased_query("director:old_tag")).to eq("new_tag")
    end

    it "applies overrides on top of stored aliases" do
      result = TagAlias.to_aliased_query("new_tag", overrides: { "new_tag" => "override_tag" })
      expect(result).to eq("override_tag")
    end

    it "includes inline comments when comments: true" do
      result = TagAlias.to_aliased_query("some_tag # my comment", comments: true)
      expect(result).to include("# my comment")
    end

    it "strips inline comments when comments: false (default)" do
      result = TagAlias.to_aliased_query("some_tag # my comment")
      expect(result).not_to include("# my comment")
    end

    it "handles multi-tag queries" do
      result = TagAlias.to_aliased_query("old_tag unrelated_tag")
      expect(result).to eq("new_tag unrelated_tag")
    end

    it "handles blank lines in multi-line queries" do
      result = TagAlias.to_aliased_query("old_tag\n\nunrelated_tag")
      expect(result).to include("new_tag")
      expect(result).to include("unrelated_tag")
    end
  end

  # ---------------------------------------------------------------------------
  # .embedded_pattern
  # ---------------------------------------------------------------------------
  describe ".embedded_pattern" do
    it "matches the [ta:id] syntax" do
      expect(TagAlias.embedded_pattern).to match("[ta:123]")
    end

    it "captures the numeric id" do
      match = "[ta:456]".match(TagAlias.embedded_pattern)
      expect(match[:id]).to eq("456")
    end

    it "does not match [ti:id] (tag implication syntax)" do
      expect(TagAlias.embedded_pattern).not_to match("[ti:123]")
    end

    it "does not match plain text" do
      expect(TagAlias.embedded_pattern).not_to match("ta:123")
    end
  end

  # ---------------------------------------------------------------------------
  # .update_cached_post_counts_for_all
  # ---------------------------------------------------------------------------
  describe ".update_cached_post_counts_for_all" do
    it "sets each alias post_count to its consequent tag's post_count" do
      consequent_tag = create(:tag, post_count: 42)
      ta = create(:active_tag_alias, antecedent_name: "ant_for_count_#{SecureRandom.hex(4)}", consequent_name: consequent_tag.name)
      ta.update_columns(post_count: 0)

      TagAlias.update_cached_post_counts_for_all

      expect(ta.reload.post_count).to eq(42)
    end
  end
end
