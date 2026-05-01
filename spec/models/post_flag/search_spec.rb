# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostFlag do
  include_context "as admin"

  describe ".search" do
    # -----------------------------------------------------------------------
    # reason_matches
    # -----------------------------------------------------------------------
    describe "reason_matches param" do
      let!(:flag_a) { create(:deletion_post_flag, reason: "flag_search_test_alpha") }
      let!(:flag_b) { create(:deletion_post_flag, reason: "flag_search_test_beta") }

      it "returns flags whose reason contains the search string" do
        expect(PostFlag.search(reason_matches: "alpha")).to include(flag_a)
      end

      it "excludes flags whose reason does not match" do
        expect(PostFlag.search(reason_matches: "alpha")).not_to include(flag_b)
      end
    end

    # -----------------------------------------------------------------------
    # is_resolved
    # -----------------------------------------------------------------------
    describe "is_resolved param" do
      let(:flag_reason)      { create(:post_flag_reason) }
      let!(:resolved_flag)   { create(:resolved_post_flag, reason_name: flag_reason.name) }
      let!(:unresolved_flag) { create(:post_flag, reason_name: flag_reason.name) }

      it "returns resolved flags when is_resolved is true" do
        expect(PostFlag.search(is_resolved: "true")).to include(resolved_flag)
        expect(PostFlag.search(is_resolved: "true")).not_to include(unresolved_flag)
      end

      it "returns unresolved flags when is_resolved is false" do
        expect(PostFlag.search(is_resolved: "false")).to include(unresolved_flag)
        expect(PostFlag.search(is_resolved: "false")).not_to include(resolved_flag)
      end
    end

    # -----------------------------------------------------------------------
    # post_id
    # -----------------------------------------------------------------------
    describe "post_id param" do
      let(:flag_reason) { create(:post_flag_reason) }
      let(:post_a) { create(:post) }
      let(:post_b) { create(:post) }
      let!(:flag_a) { create(:post_flag, reason_name: flag_reason.name, post: post_a) }
      let!(:flag_b) { create(:post_flag, reason_name: flag_reason.name, post: post_b) }

      it "returns only flags for the specified post" do
        result = PostFlag.search(post_id: post_a.id.to_s)
        expect(result).to include(flag_a)
        expect(result).not_to include(flag_b)
      end

      it "supports comma-separated post IDs" do
        result = PostFlag.search(post_id: "#{post_a.id},#{post_b.id}")
        expect(result).to include(flag_a, flag_b)
      end
    end

    # -----------------------------------------------------------------------
    # type
    # -----------------------------------------------------------------------
    describe "type param" do
      let(:flag_reason)    { create(:post_flag_reason) }
      let!(:regular_flag)  { create(:post_flag, reason_name: flag_reason.name) }
      let!(:deletion_flag) { create(:deletion_post_flag) }

      it "returns only regular flags when type is 'flag'" do
        result = PostFlag.search(type: "flag")
        expect(result).to include(regular_flag)
        expect(result).not_to include(deletion_flag)
      end

      it "returns only deletion flags when type is 'deletion'" do
        result = PostFlag.search(type: "deletion")
        expect(result).to include(deletion_flag)
        expect(result).not_to include(regular_flag)
      end

      it "returns all flags when type is not specified" do
        result = PostFlag.search({})
        expect(result).to include(regular_flag, deletion_flag)
      end
    end

    # -----------------------------------------------------------------------
    # note
    # -----------------------------------------------------------------------
    describe "note param" do
      let(:flag_reason)        { create(:post_flag_reason) }
      let!(:flag_with_note)    { create(:post_flag, reason_name: flag_reason.name, note: "unique_note_content_xyz") }
      let!(:flag_without_note) { create(:deletion_post_flag) }

      it "returns flags whose note contains the search string" do
        expect(PostFlag.search(note: "unique_note_content_xyz")).to include(flag_with_note)
      end

      it "excludes flags without a matching note" do
        expect(PostFlag.search(note: "unique_note_content_xyz")).not_to include(flag_without_note)
      end
    end

    # -----------------------------------------------------------------------
    # creator (permission-gated)
    # -----------------------------------------------------------------------
    describe "creator param" do
      let(:flag_reason) { create(:post_flag_reason) }
      let(:alice) { create(:user) }
      let!(:alice_flag) do
        original = CurrentUser.user
        CurrentUser.user = alice
        create(:post_flag, reason_name: flag_reason.name).tap { CurrentUser.user = original }
      end

      context "when CurrentUser is a janitor (can view all flaggers)" do
        it "returns flags matching the specified creator" do
          result = PostFlag.search(creator_name: alice.name)
          expect(result).to include(alice_flag)
        end
      end

      context "when CurrentUser is a regular member" do
        let(:member) { create(:user) }

        before { CurrentUser.user = member }
        after  { CurrentUser.user = nil }

        it "hides flags created by other users when searching by creator" do
          result = PostFlag.search(creator_name: alice.name)
          expect(result).not_to include(alice_flag)
        end

        it "returns own flags when searching by own name" do
          own_flag = create(:post_flag, reason_name: flag_reason.name)
          result = PostFlag.search(creator_name: member.name)
          expect(result).to include(own_flag)
        end
      end
    end

    # -----------------------------------------------------------------------
    # post_tags_match
    # -----------------------------------------------------------------------
    describe "post_tags_match param" do
      let(:flag_reason) { create(:post_flag_reason) }
      let(:tagged_post) { create(:post, tag_string: "artist:test_tag_search_artist special_tag_for_flag_search") }
      let(:other_post)  { create(:post) }
      let!(:flag_tagged) { create(:post_flag, reason_name: flag_reason.name, post: tagged_post) }
      let!(:flag_other)  { create(:post_flag, reason_name: flag_reason.name, post: other_post) }

      it "returns flags on posts matching the tag" do
        result = PostFlag.search(post_tags_match: "special_tag_for_flag_search")
        expect(result).to include(flag_tagged)
        expect(result).not_to include(flag_other)
      end
    end
  end
end
