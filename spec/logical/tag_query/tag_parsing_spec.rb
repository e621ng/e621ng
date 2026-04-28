# frozen_string_literal: true

require "rails_helper"

# Tests plain-tag parsing: prefix dispatch (must/must_not/should), wildcard expansion,
# and alias resolution. Does NOT cover metatags (see metatag-specific spec files).

RSpec.describe TagQuery, type: :model do
  include_context "as member"

  describe "plain tag parsing" do
    describe "must tags (no prefix)" do
      it "adds the tag to q[:tags][:must]" do
        tq = TagQuery.new("fluffy_tail", resolve_aliases: false)
        expect(tq[:tags][:must]).to include("fluffy_tail")
      end

      it "normalises to lowercase" do
        tq = TagQuery.new("Fluffy_Tail", resolve_aliases: false)
        expect(tq[:tags][:must]).to include("fluffy_tail")
      end

      it "stores multiple tags in order" do
        tq = TagQuery.new("tag_a tag_b tag_c", resolve_aliases: false)
        expect(tq[:tags][:must]).to eq(%w[tag_a tag_b tag_c])
      end

      it "does not add must tags to other arrays" do
        tq = TagQuery.new("solo", resolve_aliases: false)
        expect(tq[:tags][:must_not]).to be_empty
        expect(tq[:tags][:should]).to be_empty
      end
    end

    describe "must_not tags (- prefix)" do
      it "adds the tag to q[:tags][:must_not]" do
        tq = TagQuery.new("-excluded_tag", resolve_aliases: false)
        expect(tq[:tags][:must_not]).to include("excluded_tag")
      end

      it "strips the - prefix before storing" do
        tq = TagQuery.new("-my_tag", resolve_aliases: false)
        expect(tq[:tags][:must_not]).not_to include("-my_tag")
      end

      it "does not add must_not tags to other arrays" do
        tq = TagQuery.new("-excluded", resolve_aliases: false)
        expect(tq[:tags][:must]).to be_empty
        expect(tq[:tags][:should]).to be_empty
      end
    end

    describe "should tags (~ prefix)" do
      it "adds the tag to q[:tags][:should]" do
        tq = TagQuery.new("~optional_tag", resolve_aliases: false)
        expect(tq[:tags][:should]).to include("optional_tag")
      end

      it "strips the ~ prefix before storing" do
        tq = TagQuery.new("~my_tag", resolve_aliases: false)
        expect(tq[:tags][:should]).not_to include("~my_tag")
      end

      it "does not expand wildcards inside ~-prefixed tags" do
        tq = TagQuery.new("~wolf*", resolve_aliases: false)
        expect(tq[:tags][:should]).to include("wolf*")
      end
    end

    describe "mixed prefixes in a single query" do
      it "routes each token to the correct array" do
        tq = TagQuery.new("must_tag -must_not_tag ~should_tag", resolve_aliases: false)
        expect(tq[:tags][:must]).to eq(["must_tag"])
        expect(tq[:tags][:must_not]).to eq(["must_not_tag"])
        expect(tq[:tags][:should]).to eq(["should_tag"])
      end
    end

    describe "wildcard expansion" do
      before do
        create(:tag, name: "wolf_girl", post_count: 100)
        create(:tag, name: "wolf_ears", post_count: 50)
      end

      it "expands a trailing wildcard for must tags into q[:tags][:should]" do
        tq = TagQuery.new("wolf*", resolve_aliases: false)
        expect(tq[:tags][:should]).to include("wolf_girl", "wolf_ears")
      end

      it "expands a negated wildcard into q[:tags][:must_not]" do
        tq = TagQuery.new("-wolf*", resolve_aliases: false)
        expect(tq[:tags][:must_not]).to include("wolf_girl", "wolf_ears")
      end

      it "orders expanded tags by post_count descending" do
        tq = TagQuery.new("wolf*", resolve_aliases: false)
        wolf_girl_idx = tq[:tags][:should].index("wolf_girl")
        wolf_ears_idx = tq[:tags][:should].index("wolf_ears")
        expect(wolf_girl_idx).to be < wolf_ears_idx
      end

      it "stores the ~~not_found~~ sentinel when no tags match the pattern" do
        tq = TagQuery.new("zzz_no_match_xyz*", resolve_aliases: false)
        expect(tq[:tags][:should]).to include("~~not_found~~")
      end
    end

    describe "alias resolution" do
      before do
        create(:active_tag_alias, antecedent_name: "old_tag_name", consequent_name: "new_tag_name")
      end

      it "replaces an aliased must tag with its consequent" do
        tq = TagQuery.new("old_tag_name", resolve_aliases: true)
        expect(tq[:tags][:must]).to include("new_tag_name")
        expect(tq[:tags][:must]).not_to include("old_tag_name")
      end

      it "replaces an aliased must_not tag with its consequent" do
        tq = TagQuery.new("-old_tag_name", resolve_aliases: true)
        expect(tq[:tags][:must_not]).to include("new_tag_name")
        expect(tq[:tags][:must_not]).not_to include("old_tag_name")
      end

      it "replaces an aliased should tag with its consequent" do
        tq = TagQuery.new("~old_tag_name", resolve_aliases: true)
        expect(tq[:tags][:should]).to include("new_tag_name")
        expect(tq[:tags][:should]).not_to include("old_tag_name")
      end

      it "leaves tags unchanged when resolve_aliases is false" do
        tq = TagQuery.new("old_tag_name", resolve_aliases: false)
        expect(tq[:tags][:must]).to include("old_tag_name")
        expect(tq[:tags][:must]).not_to include("new_tag_name")
      end
    end
  end
end
