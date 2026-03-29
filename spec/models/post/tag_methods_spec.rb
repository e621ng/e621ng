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

      it "tracks tag_count_artist for artist-category tags" do
        post = create(:post)
        # Factory uses 'artist:...' prefix which sets category to artist
        expect(post.tag_count_artist).to be >= 1
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
        post = create(:post, tag_string: "artist:UPPERCASE_ARTIST lowercase_tag1 lowercase_tag2 lowercase_tag3 lowercase_tag4 lowercase_tag5 lowercase_tag6 lowercase_tag7 lowercase_tag8 lowercase_tag9 lowercase_tag10")
        expect(post.tag_string).not_to match(/[A-Z]/)
      end

      it "auto-creates tags that do not yet exist" do
        unique_name = "brand_new_tag_#{SecureRandom.hex(4)}"
        create(:post, tag_string: "artist:test_artist #{unique_name} " + (1..10).map { |i| "gen_tag_#{SecureRandom.hex(4)}_#{i}" }.join(" "))
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
        max = Danbooru.config.max_tags_per_post
        huge_tag_string = (1..(max + 1)).map { |n| "tag_insane_#{n}" }.join(" ")
        post = build(:post, tag_string: huge_tag_string)
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
          post = build(:post, tag_string: "artist:test_artist only_one_general_tag")
          post.valid?
          expect(post.warnings[:base].join).to match(/at least 10 general tags/)
        end
      end
    end
  end
end
