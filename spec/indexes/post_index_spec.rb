# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostIndex do
  include_context "as admin"

  describe "#as_indexed_json" do
    describe "returned hash shape" do
      subject(:indexed) { create(:post).as_indexed_json }

      it "returns a Hash" do
        expect(indexed).to be_a(Hash)
      end

      it "includes all expected top-level keys" do
        category_count_keys = TagCategory::REVERSE_MAPPING.values.map { |name| :"tag_count_#{name}" }
        expected_keys = %i[
          created_at updated_at commented_at comment_bumped_at noted_at
          id up_score down_score score fav_count tag_count change_seq
          comment_count file_size parent pools sets commenters noters
          faves upvotes downvotes children uploader approver deleter
          width height mpixels aspect_ratio duration
          tags md5 rating file_ext source description del_reason notes
          rating_locked note_locked status_locked flagged pending
          deleted has_children has_pending_replacements artverified
        ] + category_count_keys
        expect(indexed.keys).to match_array(expected_keys)
      end
    end

    describe "direct attribute mappings" do
      subject(:indexed) { post.as_indexed_json }

      let(:post) { create(:post) }

      it "maps all scalar attributes", :aggregate_failures do
        expect(indexed[:id]).to eq(post.id)
        expect(indexed[:up_score]).to eq(post.up_score)
        expect(indexed[:down_score]).to eq(post.down_score)
        expect(indexed[:score]).to eq(post.score)
        expect(indexed[:fav_count]).to eq(post.fav_count)
        expect(indexed[:file_size]).to eq(post.file_size)
        expect(indexed[:change_seq]).to eq(post.change_seq)
        expect(indexed[:tag_count]).to eq(post.tag_count)
        TagCategory::REVERSE_MAPPING.each_value do |category_name|
          key = :"tag_count_#{category_name}"
          expect(indexed[key]).to eq(post.public_send(key))
        end
        expect(indexed[:duration]).to eq(post.duration)
        expect(indexed[:md5]).to eq(post.md5)
        expect(indexed[:rating]).to eq(post.rating)
        expect(indexed[:file_ext]).to eq(post.file_ext)
        expect(indexed[:created_at]).to eq(post.created_at)
        expect(indexed[:updated_at]).to eq(post.updated_at)
      end

      context "renamed association id fields" do
        let(:uploader) { create(:user) }
        let(:approver) { create(:moderator_user) }
        let(:parent_post) { create(:post) }
        let(:post) { create(:post, uploader: uploader, approver: approver, parent_id: parent_post.id) }

        it "maps parent, uploader, approver, width, and height", :aggregate_failures do
          expect(indexed[:parent]).to eq(parent_post.id)
          expect(indexed[:uploader]).to eq(uploader.id)
          expect(indexed[:approver]).to eq(approver.id)
          expect(indexed[:width]).to eq(post.image_width)
          expect(indexed[:height]).to eq(post.image_height)
        end
      end

      context "timestamp aliases" do
        let(:base_time) { 1.day.ago.change(usec: 0) }

        before do
          post.update_columns(
            last_commented_at:      base_time,
            last_comment_bumped_at: base_time + 1.hour,
            last_noted_at:          base_time + 2.hours,
          )
          post.reload
        end

        it "maps commented_at, comment_bumped_at, and noted_at", :aggregate_failures do
          expect(indexed[:commented_at]).to eq(base_time)
          expect(indexed[:comment_bumped_at]).to eq(base_time + 1.hour)
          expect(indexed[:noted_at]).to eq(base_time + 2.hours)
        end
      end
    end

    describe "computed fields" do
      context "mpixels" do
        it "computes mpixels as image_width * image_height / 1_000_000 rounded to 2dp" do
          post = create(:post, image_width: 2000, image_height: 1000)
          expect(post.as_indexed_json[:mpixels]).to eq(2.0)
        end

        it "rounds mpixels to 2 decimal places" do
          post = create(:post, image_width: 1920, image_height: 1080)
          expect(post.as_indexed_json[:mpixels]).to eq((1920.0 * 1080 / 1_000_000).round(2))
        end
      end

      context "aspect_ratio" do
        it "computes aspect_ratio as image_width / image_height rounded to 2dp" do
          post = create(:post, image_width: 1920, image_height: 1080)
          expect(post.as_indexed_json[:aspect_ratio]).to eq((1920.0 / 1080).round(2))
        end

        it "returns 1.0 for a square image" do
          post = create(:post, image_width: 500, image_height: 500)
          expect(post.as_indexed_json[:aspect_ratio]).to eq(1.0)
        end
      end

      # FIXME: The posts table enforces NOT NULL on image_width/image_height at the DB
      #        level, so it is not possible to set these to nil via update_columns without
      #        a PG::NotNullViolation. The nil-dimension branch in as_indexed_json
      #        (mpixels → 0.0, aspect_ratio → 1.0) cannot be reached through normal
      #        post records and cannot be tested without a schema change.
      # context "nil image dimensions" do
      #   it "returns mpixels of 0.0" do ... end
      #   it "returns aspect_ratio of 1.0" do ... end
      # end
    end

    describe "string and array fields" do
      context "tags" do
        it "returns tag_string split by whitespace" do
          post = create(:post)
          post.update_columns(tag_string: "foo bar baz")
          post.reload
          expect(post.as_indexed_json[:tags]).to eq(%w[foo bar baz])
        end

        it "returns an empty array when tag_string is blank" do
          post = create(:post)
          post.update_columns(tag_string: "")
          post.reload
          expect(post.as_indexed_json[:tags]).to eq([])
        end
      end

      context "source" do
        it "returns source split by newline into an array" do
          post = create(:post)
          post.update_columns(source: "https://a.example.com\nhttps://b.example.com")
          post.reload
          expect(post.as_indexed_json[:source]).to eq(["https://a.example.com", "https://b.example.com"])
        end

        it "returns a single-element array for a single source" do
          post = create(:post)
          post.update_columns(source: "https://a.example.com")
          post.reload
          expect(post.as_indexed_json[:source]).to eq(["https://a.example.com"])
        end

        it "returns an empty array when source is blank" do
          post = create(:post)
          post.update_columns(source: "")
          post.reload
          expect(post.as_indexed_json[:source]).to eq([])
        end
      end

      context "description" do
        it "returns the description string when present" do
          post = create(:post, description: "a nice image")
          expect(post.as_indexed_json[:description]).to eq("a nice image")
        end

        it "returns nil when description is blank" do
          post = create(:post, description: "")
          expect(post.as_indexed_json[:description]).to be_nil
        end

        it "returns nil when description is only whitespace" do
          post = create(:post, description: "   ")
          expect(post.as_indexed_json[:description]).to be_nil
        end
      end
    end

    describe "boolean status fields" do
      context "with a standard active post" do
        subject(:indexed) { post.as_indexed_json }

        let(:post) { create(:post) }

        it "pending is false" do
          expect(indexed[:pending]).to be false
        end

        it "deleted is false" do
          expect(indexed[:deleted]).to be false
        end

        it "flagged is false" do
          expect(indexed[:flagged]).to be false
        end

        it "rating_locked is false" do
          expect(indexed[:rating_locked]).to be false
        end

        it "note_locked is false" do
          expect(indexed[:note_locked]).to be false
        end

        it "status_locked is false" do
          expect(indexed[:status_locked]).to be false
        end

        it "has_children is false when the post has no children" do
          expect(indexed[:has_children]).to be false
        end
      end

      it "pending is true for a pending post" do
        expect(create(:post, is_pending: true).as_indexed_json[:pending]).to be true
      end

      it "deleted is true for a deleted post" do
        expect(create(:post, is_deleted: true).as_indexed_json[:deleted]).to be true
      end

      it "flagged is true for a flagged post" do
        expect(create(:post, is_flagged: true).as_indexed_json[:flagged]).to be true
      end

      it "rating_locked is true for a rating-locked post" do
        expect(create(:post, is_rating_locked: true).as_indexed_json[:rating_locked]).to be true
      end

      it "note_locked is true for a note-locked post" do
        expect(create(:post, is_note_locked: true).as_indexed_json[:note_locked]).to be true
      end

      it "status_locked is true for a status-locked post" do
        expect(create(:post, is_status_locked: true).as_indexed_json[:status_locked]).to be true
      end

      it "has_children is true when the post has at least one child" do
        parent = create(:post)
        create(:post, parent_id: parent.id)
        parent.reload
        expect(parent.as_indexed_json[:has_children]).to be true
      end
    end

    describe "options overrides" do
      let(:post) { create(:post) }

      it "uses options[:comment_count]" do
        expect(post.as_indexed_json(comment_count: 99)[:comment_count]).to eq(99)
      end

      it "uses options[:pools]" do
        expect(post.as_indexed_json(pools: [1, 2, 3])[:pools]).to eq([1, 2, 3])
      end

      it "uses options[:sets]" do
        expect(post.as_indexed_json(sets: [7])[:sets]).to eq([7])
      end

      it "uses options[:commenters]" do
        expect(post.as_indexed_json(commenters: [5, 6])[:commenters]).to eq([5, 6])
      end

      it "uses options[:noters]" do
        expect(post.as_indexed_json(noters: [42])[:noters]).to eq([42])
      end

      it "uses options[:faves]" do
        expect(post.as_indexed_json(faves: [11, 22])[:faves]).to eq([11, 22])
      end

      it "uses options[:upvotes]" do
        expect(post.as_indexed_json(upvotes: [3])[:upvotes]).to eq([3])
      end

      it "uses options[:downvotes]" do
        expect(post.as_indexed_json(downvotes: [4])[:downvotes]).to eq([4])
      end

      it "uses options[:children]" do
        expect(post.as_indexed_json(children: [100, 101])[:children]).to eq([100, 101])
      end

      it "uses options[:notes]" do
        expect(post.as_indexed_json(notes: ["note body"])[:notes]).to eq(["note body"])
      end

      it "uses options[:deleter]" do
        expect(post.as_indexed_json(deleter: 55)[:deleter]).to eq(55)
      end

      it "uses options[:del_reason]" do
        expect(post.as_indexed_json(del_reason: "spam")[:del_reason]).to eq("spam")
      end
    end

    describe "DB fallback queries" do
      let(:post) { create(:post) }

      describe "comment_count" do
        it "returns the post's counter-cached comment_count" do
          create(:comment, post: post)
          post.reload
          expect(post.as_indexed_json[:comment_count]).to eq(post.comment_count)
        end

        it "returns 0 when the post has no comments" do
          expect(post.as_indexed_json[:comment_count]).to eq(0)
        end
      end

      describe "pools" do
        it "returns ids of pools containing this post" do
          pool = create(:pool, post_ids: [post.id])
          expect(post.as_indexed_json[:pools]).to eq([pool.id])
        end

        it "returns an empty array when the post belongs to no pools" do
          expect(post.as_indexed_json[:pools]).to eq([])
        end
      end

      describe "sets" do
        it "returns ids of post sets containing this post" do
          set = create(:post_set, post_ids: [post.id])
          expect(post.as_indexed_json[:sets]).to eq([set.id])
        end

        it "returns an empty array when the post belongs to no sets" do
          expect(post.as_indexed_json[:sets]).to eq([])
        end
      end

      describe "commenters" do
        it "returns creator_ids of undeleted comments on this post" do
          create(:comment, post: post)
          expect(post.as_indexed_json[:commenters]).to include(CurrentUser.id)
        end

        it "excludes hidden comments" do
          create(:hidden_comment, post: post)
          expect(post.as_indexed_json[:commenters]).to be_empty
        end

        it "returns an empty array when the post has no comments" do
          expect(post.as_indexed_json[:commenters]).to be_empty
        end
      end

      describe "noters" do
        it "returns creator_ids of active notes on this post" do
          create(:note, post: post)
          expect(post.as_indexed_json[:noters]).to include(CurrentUser.id)
        end

        it "excludes inactive notes" do
          create(:inactive_note, post: post)
          expect(post.as_indexed_json[:noters]).to be_empty
        end

        it "returns an empty array when the post has no active notes" do
          expect(post.as_indexed_json[:noters]).to be_empty
        end
      end

      describe "faves" do
        it "returns user_ids of users who favorited this post" do
          faver = create(:user)
          Favorite.create!(post_id: post.id, user_id: faver.id)
          expect(post.as_indexed_json[:faves]).to eq([faver.id])
        end

        it "returns an empty array when the post has no favorites" do
          expect(post.as_indexed_json[:faves]).to be_empty
        end
      end

      describe "upvotes" do
        it "returns user_ids of users who upvoted this post" do
          voter = create(:user)
          create(:post_vote, post: post, user: voter, score: 1)
          expect(post.as_indexed_json[:upvotes]).to include(voter.id)
        end

        it "does not include downvotes" do
          voter = create(:user, created_at: 4.days.ago)
          create(:down_post_vote, post: post, user: voter)
          expect(post.as_indexed_json[:upvotes]).to be_empty
        end

        it "returns an empty array when the post has no upvotes" do
          expect(post.as_indexed_json[:upvotes]).to be_empty
        end
      end

      describe "downvotes" do
        it "returns user_ids of users who downvoted this post" do
          voter = create(:user, created_at: 4.days.ago)
          create(:down_post_vote, post: post, user: voter)
          expect(post.as_indexed_json[:downvotes]).to include(voter.id)
        end

        it "does not include upvotes" do
          voter = create(:user)
          create(:post_vote, post: post, user: voter, score: 1)
          expect(post.as_indexed_json[:downvotes]).to be_empty
        end

        it "returns an empty array when the post has no downvotes" do
          expect(post.as_indexed_json[:downvotes]).to be_empty
        end
      end

      describe "children" do
        it "returns ids of posts that have this post as their parent" do
          child = create(:post, parent_id: post.id)
          expect(post.as_indexed_json[:children]).to include(child.id)
        end

        it "returns an empty array when the post has no children" do
          expect(post.as_indexed_json[:children]).to be_empty
        end
      end

      describe "notes (text bodies)" do
        it "returns bodies of active notes on this post" do
          create(:note, post: post, body: "a useful annotation")
          expect(post.as_indexed_json[:notes]).to include("a useful annotation")
        end

        it "excludes bodies of inactive notes" do
          create(:inactive_note, post: post, body: "old note")
          expect(post.as_indexed_json[:notes]).to be_empty
        end

        it "returns an empty array when the post has no active notes" do
          expect(post.as_indexed_json[:notes]).to be_empty
        end
      end

      describe "deleter" do
        it "returns the creator_id of the most recent unresolved deletion flag" do
          create(:deletion_post_flag, post: post)
          expect(post.as_indexed_json[:deleter]).to eq(CurrentUser.id)
        end

        it "returns nil when there are no deletion flags" do
          expect(post.as_indexed_json[:deleter]).to be_nil
        end

        it "returns nil when the deletion flag is resolved" do
          create(:deletion_post_flag, post: post, is_resolved: true)
          expect(post.as_indexed_json[:deleter]).to be_nil
        end
      end

      describe "del_reason" do
        it "returns the downcased reason of the most recent unresolved deletion flag" do
          create(:deletion_post_flag, post: post)
          # :deletion_post_flag reason is "Test deletion reason" — must be stored downcased
          expect(post.as_indexed_json[:del_reason]).to eq("test deletion reason")
        end

        it "returns nil when there are no deletion flags" do
          expect(post.as_indexed_json[:del_reason]).to be_nil
        end

        it "returns nil when the deletion flag is resolved" do
          create(:deletion_post_flag, post: post, is_resolved: true)
          expect(post.as_indexed_json[:del_reason]).to be_nil
        end
      end
    end

    describe "has_pending_replacements" do
      let(:post) { create(:post) }

      context "via options (options.key? pattern)" do
        it "returns true when options[:has_pending_replacements] is true" do
          expect(post.as_indexed_json(has_pending_replacements: true)[:has_pending_replacements]).to be true
        end

        it "returns false when options[:has_pending_replacements] is false, even if a pending replacement exists" do
          create(:post_replacement, post: post)
          expect(post.as_indexed_json(has_pending_replacements: false)[:has_pending_replacements]).to be false
        end
      end

      context "DB fallback" do
        it "returns true when the post has a pending replacement" do
          create(:post_replacement, post: post)
          expect(post.as_indexed_json[:has_pending_replacements]).to be true
        end

        it "returns false when the post has no replacements" do
          expect(post.as_indexed_json[:has_pending_replacements]).to be false
        end

        it "returns false when all replacements are non-pending" do
          create(:approved_post_replacement, post: post)
          expect(post.as_indexed_json[:has_pending_replacements]).to be false
        end
      end
    end

    describe "artverified" do
      let(:uploader) { create(:user) }
      # Artist#categorize_tag (after_save) calls Tag.find_or_create_by_name("artist:#{name}"),
      # so the artist-category tag is created automatically — no separate artist_tag needed.
      let(:artist) { create(:artist, linked_user_id: uploader.id) }
      let(:verified_post) { create(:post, uploader: uploader, tag_string: artist.name) }
      let(:unverified_post) { create(:post) }

      context "via options (options.key? pattern)" do
        it "returns true when options[:artverified] is true" do
          expect(unverified_post.as_indexed_json(artverified: true)[:artverified]).to be true
        end

        it "returns false when options[:artverified] is false, even if the uploader has a linked artist" do
          expect(verified_post.as_indexed_json(artverified: false)[:artverified]).to be false
        end
      end

      context "DB fallback" do
        it "returns false when the uploader has no linked verified artists" do
          expect(unverified_post.as_indexed_json[:artverified]).to be false
        end

        it "returns true when the uploader is the linked artist for one of the post's artist tags" do
          expect(verified_post.as_indexed_json[:artverified]).to be true
        end
      end
    end

    describe "options isolation" do
      let(:post) { create(:post) }

      it "passing one option key does not affect unrelated fields" do
        indexed = post.as_indexed_json(pools: [1, 2])
        expect(indexed[:sets]).to eq([])
        expect(indexed[:faves]).to eq([])
      end

      it "unknown keys in options do not raise" do
        expect { post.as_indexed_json(unknown_key: "value") }.not_to raise_error
      end
    end
  end
end
