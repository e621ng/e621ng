# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagAlias do
  include_context "as admin"

  # ---------------------------------------------------------------------------
  # TransitiveChecks module
  #
  # list_transitives detects two kinds of chains on the record being built:
  #   :alias      — an existing alias whose consequent_name == our antecedent_name
  #   :implication — an existing implication where antecedent_name or
  #                  consequent_name == our antecedent_name
  # ---------------------------------------------------------------------------

  describe "#list_transitives" do
    it "returns an empty array when no chains exist" do
      ta = build(:tag_alias, antecedent_name: "standalone_ant", consequent_name: "standalone_con")
      expect(ta.list_transitives).to be_empty
    end

    it "detects a transitive alias chain (existing alias points to our antecedent)" do
      # first_tag → mid_tag already exists; we're building mid_tag → final_tag
      create(:active_tag_alias, antecedent_name: "first_tag", consequent_name: "mid_tag")
      ta = build(:tag_alias, antecedent_name: "mid_tag", consequent_name: "final_tag")

      transitives = ta.list_transitives
      expect(transitives).not_to be_empty
      expect(transitives.first[0]).to eq(:alias)
    end

    it "detects an implication where our antecedent_name is the implication's antecedent" do
      create(:active_tag_implication, antecedent_name: "ant_tag", consequent_name: "imp_con")
      ta = build(:tag_alias, antecedent_name: "ant_tag", consequent_name: "alias_con")

      transitives = ta.list_transitives
      expect(transitives).not_to be_empty
      expect(transitives.first[0]).to eq(:implication)
    end

    it "detects an implication where our antecedent_name is the implication's consequent" do
      create(:active_tag_implication, antecedent_name: "imp_ant", consequent_name: "ant_tag")
      ta = build(:tag_alias, antecedent_name: "ant_tag", consequent_name: "alias_con")

      transitives = ta.list_transitives
      expect(transitives).not_to be_empty
      expect(transitives.first[0]).to eq(:implication)
    end

    it "ignores deleted aliases when checking for chains" do
      existing = create(:tag_alias, antecedent_name: "first_tag", consequent_name: "mid_tag")
      existing.update_columns(status: "deleted")
      ta = build(:tag_alias, antecedent_name: "mid_tag", consequent_name: "final_tag")

      expect(ta.list_transitives).to be_empty
    end
  end

  describe "#has_transitives" do
    it "returns false when no chains exist" do
      ta = build(:tag_alias, antecedent_name: "clean_ant", consequent_name: "clean_con")
      expect(ta.has_transitives).to be false
    end

    it "returns true when a transitive alias chain exists" do
      create(:active_tag_alias, antecedent_name: "prev_tag", consequent_name: "mid_tag")
      ta = build(:tag_alias, antecedent_name: "mid_tag", consequent_name: "dest_tag")
      expect(ta.has_transitives).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # .preload_transitives
  # ---------------------------------------------------------------------------

  describe ".preload_transitives" do
    def select_query_count(&block)
      count = 0
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        count += 1 if payload[:sql].start_with?("SELECT")
      end
      block.call
      ActiveSupport::Notifications.unsubscribe(subscriber)
      count
    end

    it "is a no-op on an empty collection" do
      expect { TagAlias.preload_transitives([]) }.not_to raise_error
    end

    it "sets has_transitives to false when there are no chains" do
      ta = create(:tag_alias, antecedent_name: "solo_ant", consequent_name: "solo_con")
      TagAlias.preload_transitives([ta])
      expect(ta.has_transitives).to be false
    end

    it "sets has_transitives to true when a transitive alias exists" do
      create(:active_tag_alias, antecedent_name: "first_tag", consequent_name: "mid_tag")
      ta = create(:tag_alias, antecedent_name: "mid_tag", consequent_name: "final_tag")
      TagAlias.preload_transitives([ta])
      expect(ta.has_transitives).to be true
    end

    it "populates the alias transitive entry with the correct tuple shape" do
      existing = create(:active_tag_alias, antecedent_name: "chain_a", consequent_name: "chain_b")
      ta = create(:tag_alias, antecedent_name: "chain_b", consequent_name: "chain_c")
      TagAlias.preload_transitives([ta])

      entry = ta.list_transitives.first
      expect(entry[0]).to eq(:alias)
      expect(entry[1]).to eq(existing)
      expect(entry[2]).to eq("chain_a")
      expect(entry[3]).to eq("chain_b")
      expect(entry[4]).to eq("chain_c")
    end

    it "detects an implication where our antecedent_name matches the implication antecedent" do
      create(:active_tag_implication, antecedent_name: "ant_tag", consequent_name: "imp_con")
      ta = create(:tag_alias, antecedent_name: "ant_tag", consequent_name: "alias_con")
      TagAlias.preload_transitives([ta])

      entry = ta.list_transitives.first
      expect(entry[0]).to eq(:implication)
      expect(entry[4]).to eq("alias_con")
    end

    it "detects an implication where our antecedent_name matches the implication consequent" do
      create(:active_tag_implication, antecedent_name: "imp_ant", consequent_name: "ant_tag")
      ta = create(:tag_alias, antecedent_name: "ant_tag", consequent_name: "alias_con")
      TagAlias.preload_transitives([ta])

      entry = ta.list_transitives.first
      expect(entry[0]).to eq(:implication)
      expect(entry[5]).to eq("alias_con")
    end

    it "populates all records in the batch" do
      create(:active_tag_alias, antecedent_name: "x", consequent_name: "a")
      create(:active_tag_alias, antecedent_name: "y", consequent_name: "b")
      ta_a = create(:tag_alias, antecedent_name: "a", consequent_name: "z")
      ta_b = create(:tag_alias, antecedent_name: "b", consequent_name: "z")
      ta_c = create(:tag_alias, antecedent_name: "c", consequent_name: "z")

      TagAlias.preload_transitives([ta_a, ta_b, ta_c])

      expect(ta_a.has_transitives).to be true
      expect(ta_b.has_transitives).to be true
      expect(ta_c.has_transitives).to be false
    end

    it "skips records that already have @transitives memoized" do
      ta = create(:tag_alias, antecedent_name: "pre_memoized", consequent_name: "con")
      ta.instance_variable_set(:@transitives, [:sentinel])
      ta.instance_variable_set(:@has_transitives, true)

      create(:active_tag_alias, antecedent_name: "upstream", consequent_name: "pre_memoized")
      TagAlias.preload_transitives([ta])

      expect(ta.instance_variable_get(:@transitives)).to eq([:sentinel])
    end

    it "ignores aliases and implications with deleted status" do
      existing = create(:tag_alias, antecedent_name: "del_a", consequent_name: "del_b")
      existing.update_columns(status: "deleted")
      ta = create(:tag_alias, antecedent_name: "del_b", consequent_name: "del_c")
      TagAlias.preload_transitives([ta])
      expect(ta.has_transitives).to be false
    end

    it "fires exactly 2 SELECT queries regardless of how many records are passed" do
      records = Array.new(3) { |i| create(:tag_alias, antecedent_name: "bulk_tag_#{i}", consequent_name: "bulk_con_#{i}") }

      n = select_query_count { TagAlias.preload_transitives(records) }
      expect(n).to eq(2)
    end

    it "fires 2 queries even when transitive matches exist across multiple records" do
      records = Array.new(3) do |i|
        create(:active_tag_alias, antecedent_name: "upstream_#{i}", consequent_name: "target_#{i}")
        create(:tag_alias, antecedent_name: "target_#{i}", consequent_name: "downstream_#{i}")
      end

      n = select_query_count { TagAlias.preload_transitives(records) }
      expect(n).to eq(2)
    end
  end
end
