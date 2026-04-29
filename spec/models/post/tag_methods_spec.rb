# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "TagMethods" do
    describe "#tag_array" do
      it "returns the tag_string as an array of tag names" do
        post = create(:post)
        expect(post.tag_array).to be_an(Array)
        expect(post.tag_array).not_to be_empty
      end

      it "includes every tag from the stored tag_string" do
        post = create(:post)
        post.tag_string.split.each do |tag_name|
          expect(post.tag_array).to include(tag_name)
        end
      end
    end

    describe "#has_tag?" do
      it "returns true when the post has the specified tag" do
        post = create(:post)
        tag_name = post.tag_array.first
        expect(post.has_tag?(tag_name)).to be true
      end

      it "returns false when the post does not have the specified tag" do
        post = create(:post)
        expect(post.has_tag?("definitely_not_a_real_tag_xyzzy")).to be false
      end
    end

    describe "#add_tag" do
      it "appends the tag to tag_string in memory" do
        post = create(:post)
        post.add_tag("new_tag")
        expect(post.tag_array).to include("new_tag")
      end

      it "does not persist until saved" do
        post = create(:post)
        post.add_tag("unsaved_tag")
        expect(post.reload.tag_array).not_to include("unsaved_tag")
      end
    end

    describe "#remove_tag" do
      it "removes the tag from tag_string in memory" do
        post = create(:post)
        tag_to_remove = post.tag_array.first
        post.remove_tag(tag_to_remove)
        expect(post.tag_array).not_to include(tag_to_remove)
      end
    end

    describe "tag count columns" do
      it "sets tag_count to the number of tags after save" do
        post = create(:post)
        expect(post.tag_count).to be > 0
      end

      it "tracks tag_count for category-1 tags" do
        post = create(:post)
        # Factory adds one category-1 tag (artist/director depending on fork)
        expect(post.public_send(:"tag_count_#{TagCategory::REVERSE_MAPPING[1]}")).to be >= 1
      end

      it "tracks tag_count_general for general-category tags" do
        post = create(:post)
        expect(post.tag_count_general).to be >= 10
      end

      it "updates tag_count_general when tags are changed" do
        post = create(:post)
        original_count = post.tag_count_general
        new_tag = create(:tag)
        post.update!(tag_string: post.tag_string + " #{new_tag.name}")
        expect(post.reload.tag_count_general).to eq(original_count + 1)
      end
    end

    describe "normalize_tags" do
      it "sorts tag_string alphabetically after save" do
        post = create(:post)
        sorted = post.tag_string.split.sort.join(" ")
        expect(post.tag_string).to eq(sorted)
      end

      it "downcases all tag names" do
        cat = TagCategory::REVERSE_MAPPING[1]
        post = create(:post, tag_string: "#{cat}:UPPERCASE_TAG lowercase_tag1 lowercase_tag2 lowercase_tag3 lowercase_tag4 lowercase_tag5 lowercase_tag6 lowercase_tag7 lowercase_tag8 lowercase_tag9 lowercase_tag10")
        expect(post.tag_string).not_to match(/[A-Z]/)
      end

      it "auto-creates tags that do not yet exist" do
        cat = TagCategory::REVERSE_MAPPING[1]
        unique_name = "brand_new_tag_#{SecureRandom.hex(4)}"
        create(:post, tag_string: "#{cat}:test_tag #{unique_name} " + (1..10).map { |i| "gen_tag_#{SecureRandom.hex(4)}_#{i}" }.join(" "))
        expect(Tag.find_by(name: unique_name)).not_to be_nil
      end

      it "replaces an empty tag list with 'tagme'" do
        # We can test this by bypassing normal creation and using a direct update
        post = create(:post)
        post.update!(tag_string_diff: post.tag_array.map { |t| "-#{t}" }.join(" "))
        expect(post.reload.tag_array).to include("tagme")
      end
    end

    describe "apply_tag_diff" do
      it "adds tags listed without a minus prefix" do
        post = create(:post)
        new_tag = create(:tag)
        post.update!(tag_string_diff: new_tag.name)
        expect(post.reload.tag_array).to include(new_tag.name)
      end

      it "removes tags listed with a minus prefix" do
        post = create(:post)
        tag_to_remove = post.tag_array.first
        post.update!(tag_string_diff: "-#{tag_to_remove}")
        expect(post.reload.tag_array).not_to include(tag_to_remove)
      end
    end

    describe "locked tags" do
      it "forcefully re-adds a locked tag that was omitted from the edit" do
        post = create(:post)
        locked_name = post.tag_array.first
        post.update_columns(locked_tags: locked_name)

        # Try to save without the locked tag
        remaining_tags = post.reload.tag_array.reject { |t| t == locked_name }.join(" ")
        post.update!(tag_string: remaining_tags)
        expect(post.reload.tag_array).to include(locked_name)
      end

      it "adds a warning when a locked tag is forcefully re-added" do
        post = create(:post)
        locked_name = post.tag_array.first
        post.update_columns(locked_tags: locked_name)

        remaining_tags = post.reload.tag_array.reject { |t| t == locked_name }.join(" ")
        post.tag_string = remaining_tags
        post.valid?
        expect(post.warnings[:base].join).to match(/Forcefully added/)
      end

      it "adds a warning when a locked removal is enforced" do
        post = create(:post)
        tag_to_lock_out = post.tag_array.first
        # Assigning locked_tags directly marks it as changed, which triggers
        # should_process_tags? => locked_tags_changed? == true
        post.assign_attributes(locked_tags: "-#{tag_to_lock_out}")
        post.valid?
        expect(post.warnings[:base].join).to match(/Forcefully removed/)
      end
    end

    describe "pre-metatag processing" do
      describe "rating: metatag" do
        it "changes the post rating when 'rating:q' is in the tag_string" do
          post = create(:post, rating: "s")
          post.update!(tag_string: "#{post.tag_string} rating:q")
          expect(post.reload.rating).to eq("q")
        end
      end

      describe "parent: metatag" do
        it "sets parent_id when 'parent:N' is in the tag_string" do
          parent = create(:post)
          child  = create(:post)
          child.update!(tag_string: child.tag_string + " parent:#{parent.id}")
          expect(child.reload.parent_id).to eq(parent.id)
        end

        it "clears parent_id when 'parent:none' is in the tag_string" do
          parent = create(:post)
          child  = create(:post, parent: parent)
          child.update!(tag_string: "#{child.tag_string} parent:none")
          expect(child.reload.parent_id).to be_nil
        end
      end

      describe "source: metatag" do
        it "sets the source when 'source:url' is in the tag_string" do
          post = create(:post, source: "")
          post.update!(tag_string: "#{post.tag_string} source:https://example.com")
          expect(post.reload.source).to include("example.com")
        end
      end
    end

    describe "tag_count_not_insane validation" do
      it "is invalid when tag count exceeds the maximum" do
        allow(Danbooru.config.custom_configuration).to receive(:max_tags_per_post).and_return(5)
        post = build(:post, tag_string: "a b c d e f")
        expect(post).not_to be_valid
        expect(post.errors[:tag_string]).to be_present
      end
    end

    describe "warning validators" do
      describe "has_artist_tag warning" do
        it "adds a warning on new posts without an artist tag" do
          # Build a post with no artist-category tags
          post = build(:post, tag_string: "tag1 tag2 tag3 tag4 tag5 tag6 tag7 tag8 tag9 tag10")
          post.valid?
          expect(post.warnings[:base].join).to match(/Artist tag is required/)
        end

        it "does not add the artist warning on existing posts" do
          post = create(:post)
          post.update_columns(tag_string: "tag1 tag2")
          post.reload.tag_string = "tag1"
          post.valid?
          expect(post.warnings[:base].join).not_to match(/Artist tag is required/)
        end
      end

      describe "has_enough_tags warning" do
        it "adds a warning on new posts with fewer than 10 general tags" do
          post = build(:post, tag_string: "#{TagCategory::REVERSE_MAPPING[1]}:test_tag only_one_general_tag")
          post.valid?
          expect(post.warnings[:base].join).to match(/at least 10 general tags/)
        end
      end
    end

    describe "#tags_was" do
      it "returns Tag.where scoped to the previous tag string" do
        post = create(:post)
        old_names = post.tag_array.dup
        new_tag = create(:tag)
        post.update!(tag_string: post.tag_string + " #{new_tag.name}")
        expect(post.tags_was.map(&:name)).to match_array(old_names)
      end
    end

    describe "#merge_old_changes" do
      describe "when old_tag_string is set (concurrent edit merging)" do
        it "merges tag changes by keeping concurrent additions and applying user removals" do
          tag_a = create(:tag, name: "merge_tag_a")
          tag_b = create(:tag, name: "merge_tag_b")
          create(:tag, name: "merge_tag_c")
          tag_d = create(:tag, name: "merge_tag_d")

          post = create(:post)
          # Simulate concurrent edit: DB now has A B D
          post.update_columns(tag_string: "merge_tag_a merge_tag_b merge_tag_d")
          post.reload

          # User saw A B C, submits A C (removing B)
          post.old_tag_string = "merge_tag_a merge_tag_b merge_tag_c"
          post.tag_string = "merge_tag_a merge_tag_c"
          post.save!

          expect(post.tag_array).to include(tag_a.name, tag_d.name)
          expect(post.tag_array).not_to include(tag_b.name)
        end
      end

      describe "when old_rating matches submitted rating (user did not intend to change it)" do
        it "reverts rating to the database value" do
          post = create(:post, rating: "s")
          post.update_columns(rating: "q")
          post.reload

          post.old_rating = "s"
          post.rating = "s"
          post.save!

          expect(post.reload.rating).to eq("q")
        end
      end

      describe "when old_source matches submitted source (user did not intend to change it)" do
        it "reverts source to the database value" do
          post = create(:post, source: "https://old.example.com")
          post.update_columns(source: "https://new.example.com")
          post.reload

          post.old_source = "https://old.example.com"
          post.source = "https://old.example.com"
          post.save!

          expect(post.reload.source).to include("new.example.com")
        end
      end

      describe "when old_parent_id matches submitted parent_id (user did not intend to change it)" do
        it "reverts parent_id to the previous value in memory after validation" do
          parent_a = create(:post)
          parent_b = create(:post)
          # DB state: child's current parent is parent_b
          child = create(:post, parent: parent_b)
          child.reload

          # User saw parent_a, submits parent_a (unchanged intent) — merge should revert to parent_b
          child.old_parent_id = parent_a.id.to_s
          child.parent_id = parent_a.id
          child.valid?

          expect(child.parent_id).to eq(parent_b.id)
        end
      end
    end

    describe "normalize_tags — locked_tags blank string → nil" do
      it "converts a whitespace-only locked_tags to nil" do
        post = create(:post)
        post.update_columns(locked_tags: "some_tag")
        post.reload
        post.update!(locked_tags: "   ")
        expect(post.reload.locked_tags).to be_nil
      end
    end

    describe "add_automatic_tags" do
      it "adds wide_image and long_image for very wide posts" do
        post = create(:post, image_width: 4096, image_height: 512)
        expect(post.tag_array).to include("wide_image", "long_image")
      end

      it "adds tall_image and long_image for very tall posts" do
        post = create(:post, image_width: 512, image_height: 4096)
        expect(post.tag_array).to include("tall_image", "long_image")
      end
    end

    describe "apply_casesensitive_metatags" do
      describe "source:none metatag" do
        it "clears the source" do
          post = create(:post, source: "https://example.com")
          post.update!(tag_string: "#{post.tag_string} source:none")
          expect(post.reload.source).to eq("")
        end
      end

      describe "quoted source metatag" do
        it "sets the source to the value inside quotes" do
          post = create(:post, source: "")
          post.update!(tag_string: "#{post.tag_string} source:\"https://quoted.example.com\"")
          expect(post.reload.source).to include("https://quoted.example.com")
        end
      end

      describe "newpool: metatag" do
        it "creates a new Pool when none exists with that name" do
          pool_name = "new_metatag_pool_#{SecureRandom.hex(4)}"
          post = create(:post)
          expect { post.update!(tag_string: "#{post.tag_string} newpool:#{pool_name}") }
            .to change { Pool.where(name: pool_name).count }.from(0).to(1)
        end

        it "does not create a duplicate Pool when one already exists with that name" do
          existing_pool = create(:pool)
          post = create(:post)
          expect { post.update!(tag_string: "#{post.tag_string} newpool:#{existing_pool.name}") }
            .not_to(change(Pool, :count))
        end
      end
    end

    describe "filter_metatags — bad type changes warning" do
      it "warns when a category prefix is used for a tag that already exists with a different category" do
        existing_tag = create(:tag, name: "existing_general_tag", category: Tag.categories.general,
                                    post_count: Danbooru.config.tag_type_change_cutoff + 1)
        post = create(:post)
        # Trying to use a category prefix for a tag that is already category general
        post.tag_string = "#{post.tag_string} #{TagCategory::REVERSE_MAPPING[1]}:#{existing_tag.name}"
        post.valid?
        expect(post.warnings[:base].join).to match(/Failed to update the tag category/)
      end
    end

    describe "apply_post_metatags" do
      describe "-pool:<id> metatag" do
        it "removes the post from the pool" do
          pool = create(:pool)
          post = create(:post)
          pool.add!(post)
          post.update!(tag_string: "#{post.tag_string} -pool:#{pool.id}")
          expect(post.reload.pool_ids).not_to include(pool.id)
        end
      end

      describe "-pool:<name> metatag" do
        it "removes the post from the pool by name" do
          pool = create(:pool)
          post = create(:post)
          pool.add!(post)
          post.update!(tag_string: "#{post.tag_string} -pool:#{pool.name}")
          expect(post.reload.pool_ids).not_to include(pool.id)
        end
      end

      describe "pool:<id> metatag" do
        it "adds the post to the pool by id" do
          pool = create(:pool)
          post = create(:post)
          post.update!(tag_string: "#{post.tag_string} pool:#{pool.id}")
          expect(post.reload.pool_ids).to include(pool.id)
        end
      end

      describe "pool:<name> metatag" do
        it "adds the post to an existing pool by name" do
          pool = create(:pool)
          post = create(:post)
          post.update!(tag_string: "#{post.tag_string} pool:#{pool.name}")
          expect(post.reload.pool_ids).to include(pool.id)
        end
      end

      describe "set:<id> metatag" do
        it "adds the post to the set by id when the user can edit it" do
          post_set = create(:post_set, creator: CurrentUser.user)
          post = create(:post)
          post.update!(tag_string: "#{post.tag_string} set:#{post_set.id}")
          expect(post.reload.set_ids).to include(post_set.id)
        end
      end

      describe "-set:<id> metatag" do
        it "removes the post from the set by id when the user can edit it" do
          post_set = create(:post_set, creator: CurrentUser.user)
          post = create(:post)
          post_set.add!(post)
          post.update!(tag_string: "#{post.tag_string} -set:#{post_set.id}")
          expect(post.reload.set_ids).not_to include(post_set.id)
        end
      end

      describe "set:<shortname> metatag" do
        it "adds the post to the set by shortname" do
          post_set = create(:post_set, creator: CurrentUser.user)
          post = create(:post)
          post.update!(tag_string: "#{post.tag_string} set:#{post_set.shortname}")
          expect(post.reload.set_ids).to include(post_set.id)
        end
      end

      describe "-set:<shortname> metatag" do
        it "removes the post from the set by shortname" do
          post_set = create(:post_set, creator: CurrentUser.user)
          post = create(:post)
          post_set.add!(post)
          post.update!(tag_string: "#{post.tag_string} -set:#{post_set.shortname}")
          expect(post.reload.set_ids).not_to include(post_set.id)
        end
      end

      describe "child:none metatag" do
        it "removes the parent link from all children" do
          parent = create(:post)
          child1 = create(:post, parent: parent)
          child2 = create(:post, parent: parent)
          parent.update!(tag_string: "#{parent.tag_string} child:none")

          child1.reload
          child2.reload
          expect(child1.parent_id).to be_nil
          expect(child1.versions.last.reason).to eq("Removed as child of post ##{parent.id}")
          expect(child2.parent_id).to be_nil
          expect(child2.versions.last.reason).to eq("Removed as child of post ##{parent.id}")
        end
      end

      describe "-child:<id> metatag" do
        it "removes the parent link from the specified child" do
          parent = create(:post)
          child = create(:post, parent: parent)
          parent.update!(tag_string: "#{parent.tag_string} -child:#{child.id}")

          child.reload
          expect(child.parent_id).to be_nil
          expect(child.versions.last.reason).to eq("Removed as child of post ##{parent.id}")
        end
      end

      describe "child:<id> metatag" do
        it "sets the post as the parent of the specified post" do
          parent = create(:post)
          other = create(:post)
          parent.update!(tag_string: "#{parent.tag_string} child:#{other.id}")

          other.reload
          expect(other.parent_id).to eq(parent.id)
          expect(other.versions.last.reason).to eq("Added as child of post ##{parent.id}")
        end
      end
    end

    describe "apply_pre_metatags — lock metatags" do
      describe "locked:notes metatag" do
        it "sets is_note_locked to true" do
          post = create(:post)
          post.update!(tag_string: "#{post.tag_string} locked:notes")
          expect(post.reload.is_note_locked).to be true
        end

        it "sets is_note_locked to false with -locked:notes" do
          post = create(:note_locked_post)
          post.update!(tag_string: "#{post.tag_string} -locked:notes")
          expect(post.reload.is_note_locked).to be false
        end
      end

      describe "locked:rating metatag" do
        it "sets is_rating_locked to true" do
          post = create(:post)
          post.update!(tag_string: "#{post.tag_string} locked:rating")
          expect(post.reload.is_rating_locked).to be true
        end
      end

      describe "locked:status metatag" do
        it "sets is_status_locked to true" do
          post = create(:post)
          post.update!(tag_string: "#{post.tag_string} locked:status")
          expect(post.reload.is_status_locked).to be true
        end
      end

      describe "-parent:<id> metatag" do
        it "clears parent_id when the current parent matches" do
          parent = create(:post)
          child = create(:post, parent: parent)
          child.update!(tag_string: "#{child.tag_string} -parent:#{parent.id}")
          expect(child.reload.parent_id).to be_nil
        end

        it "does not clear parent_id when the current parent does not match" do
          parent_a = create(:post)
          parent_b = create(:post)
          child = create(:post, parent: parent_a)
          child.update!(tag_string: "#{child.tag_string} -parent:#{parent_b.id}")
          expect(child.reload.parent_id).to eq(parent_a.id)
        end
      end
    end

    describe "#has_tag? with recurse: true" do
      it "returns true when the post directly has the tag" do
        post = create(:post)
        tag_name = post.tag_array.first
        expect(post.has_tag?(tag_name, recurse: true)).to be true
      end

      it "returns false when the post does not have the tag" do
        post = create(:post)
        expect(post.has_tag?("definitely_absent_tag_xyz", recurse: true)).to be false
      end
    end

    describe "#fetch_tags" do
      it "returns matching tags without recursion" do
        post = create(:post)
        tag_name = post.tag_array.first
        result = post.fetch_tags(tag_name, recurse: false)
        expect(result).to include(tag_name)
      end

      it "returns matching tags with recursion" do
        post = create(:post)
        tag_name = post.tag_array.first
        result = post.fetch_tags(tag_name, recurse: true)
        expect(result).to include(tag_name)
      end
    end

    describe "#inject_tag_categories" do
      it "stores the provided category map and groups typed_tags accordingly" do
        post = create(:post)
        tag_name = post.tag_array.first
        post.inject_tag_categories({ tag_name => 0 })
        expect(post.typed_tags(0)).to include(tag_name)
      end
    end

    describe "#copy_tags_to_parent" do
      it "appends the post's tags to the parent tag_string" do
        parent = create(:post)
        child = create(:post, parent: parent)
        child.copy_tags_to_parent
        child.tag_array.each do |tag_name|
          expect(parent.tag_string).to include(tag_name)
        end
      end

      it "sets the parent's edit_reason to indicate the merge" do
        parent = create(:post)
        child = create(:post, parent: parent)
        child.copy_tags_to_parent
        expect(parent.edit_reason).to eq("Merged from post ##{child.id}")
      end

      it "does nothing when the post has no parent" do
        child = create(:post, parent_id: nil)
        expect { child.copy_tags_to_parent }.not_to raise_error
      end
    end

    describe "#known_artist_tags" do
      it "excludes tags in NON_KNOWN_ARTIST_TAGS" do
        unknown_tag_name = Post::NON_KNOWN_ARTIST_TAGS.first
        create(:tag, name: unknown_tag_name, category: 1)
        post = create(:post, tag_string: "#{unknown_tag_name} #{(1..10).map { |i| "gen_#{i}" }.join(' ')}")
        expect(post.known_artist_tags.map(&:name)).not_to include(unknown_tag_name)
      end

      it "includes category-1 tags not in NON_KNOWN_ARTIST_TAGS" do
        post = create(:post)
        # NOTE: the e6ai fork does not have artist tags, but the method
        # is still named artist_tags for the sake of compatibility.
        cat1_tag_names = post.artist_tags.map(&:name)
        expect(post.known_artist_tags.map(&:name)).to match_array(
          cat1_tag_names.reject { |n| Post::NON_KNOWN_ARTIST_TAGS.include?(n) },
        )
      end
    end

    describe "#avoid_posting_artists" do
      skip "Avoid postings routes not available in this fork" unless Rails.application.routes.url_helpers.method_defined?(:avoid_postings_path)

      it "returns AvoidPosting records for artist tags on the post" do
        artist = create(:artist)
        avoid = create(:avoid_posting, artist: artist)
        # Use artist: prefix to create the tag with artist category
        post = create(:post, tag_string: "artist:#{artist.name} " + (1..10).map { |i| "gen_#{i}" }.join(" "))
        expect(post.avoid_posting_artists).to include(avoid)
      end

      it "returns an empty array when the post has no artist tags" do
        post = create(:post, tag_string: (1..10).map { |i| "gen_only_#{i}" }.join(" "))
        expect(post.avoid_posting_artists).to eq([])
      end
    end
  end
end
