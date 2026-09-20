# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "VersionMethods" do
    describe "#create_version (via after_save)" do
      it "creates a PostVersion record when a new post is saved" do
        expect { create(:post) }.to change(PostVersion, :count).by(1)
      end

      it "creates an additional PostVersion when watched attributes change" do
        post = create(:post)
        expect { post.update!(rating: "e") }.to change(PostVersion, :count).by(1)
      end

      it "does not create a PostVersion when only unwatched attributes change" do
        post = create(:post)
        # fav_count is not a watched attribute
        expect { post.update_columns(fav_count: 99) }.not_to change(PostVersion, :count)
      end

      it "skips versioning when do_not_version_changes is set" do
        post = create(:post)
        post.do_not_version_changes = true
        expect { post.update!(description: "changed") }.not_to change(PostVersion, :count)
      end
    end

    describe "original tags" do
      it "stores the submitted tags on the first version" do
        post = create(:post, tag_string: "tagme foo")
        expect(post.versions.last.original_tags_array).to match_array(%w[tagme foo])
      end

      it "stores only the tags that were added on a tag_string edit" do
        post = Post.find(create(:post, tag_string: "tagme foo").id)
        post.update!(tag_string: "tagme foo bar")
        expect(post.versions.last.original_tags).to eq("bar")
      end

      it "stores the raw tag_string_diff on a diff edit" do
        post = Post.find(create(:post, tag_string: "tagme foo").id)
        post.tag_string_diff = "bar -foo"
        post.save!
        expect(post.versions.last.original_tags).to eq("bar -foo")
      end

      it "strips post metatags and category prefixes" do
        post = Post.find(create(:post, tag_string: "tagme foo").id)
        post.tag_string_diff = "fav:me pool:1 artist:bar_artist baz"
        post.save!
        expect(post.versions.last.original_tags_array).to match_array(%w[bar_artist baz])
      end

      it "keeps aliased tags as typed instead of resolving them" do
        create(:active_tag_alias, antecedent_name: "old_name", consequent_name: "new_name")
        post = create(:post, tag_string: "tagme old_name")
        version = post.versions.last
        expect(post.tag_array).to include("new_name")
        expect(version.original_tags_array).to include("old_name")
        expect(version.original_tags_array).not_to include("new_name")
      end

      it "keeps aliased tags as typed on a tag_string_diff edit" do
        create(:active_tag_alias, antecedent_name: "old_name", consequent_name: "new_name")
        post = Post.find(create(:post, tag_string: "tagme foo").id)
        post.tag_string_diff = "old_name"
        post.save!
        expect(post.tag_array).to include("new_name")
        expect(post.versions.last.original_tags).to eq("old_name")
      end

      it "does not include tags added by implications" do
        create(:active_tag_implication, antecedent_name: "child_tag", consequent_name: "parent_tag")
        post = create(:post, tag_string: "tagme child_tag")
        version = post.versions.last
        expect(post.tag_array).to include("child_tag", "parent_tag")
        expect(version.original_tags_array).to include("child_tag")
        expect(version.original_tags_array).not_to include("parent_tag")
      end

      it "does not include tags added by implications on an edit" do
        create(:active_tag_implication, antecedent_name: "child_tag", consequent_name: "parent_tag")
        post = Post.find(create(:post, tag_string: "tagme foo").id)
        post.update!(tag_string: "tagme foo child_tag")
        expect(post.tag_array).to include("parent_tag")
        expect(post.versions.last.original_tags).to eq("child_tag")
      end

      it "is empty when the tags did not change" do
        post = Post.find(create(:post).id)
        post.update!(rating: "e")
        expect(post.versions.last.original_tags).to eq("")
      end
    end

    describe "#saved_change_to_watched_attributes?" do
      it "returns true after a rating change" do
        post = create(:post, rating: "s")
        post.update!(rating: "e")
        expect(post.saved_change_to_watched_attributes?).to be true
      end

      it "returns true after a source change" do
        post = create(:post, source: "https://old.example.com")
        post.update!(source: "https://new.example.com")
        expect(post.saved_change_to_watched_attributes?).to be true
      end

      it "returns true after a tag_string change" do
        post = create(:post)
        new_tag = create(:tag)
        post.update!(tag_string: post.tag_string + " #{new_tag.name}")
        expect(post.saved_change_to_watched_attributes?).to be true
      end

      it "returns true after a description change" do
        post = create(:post, description: "original")
        post.update!(description: "updated")
        expect(post.saved_change_to_watched_attributes?).to be true
      end

      it "returns true after a parent_id change" do
        parent = create(:post)
        post = create(:post)
        post.update!(parent_id: parent.id)
        expect(post.saved_change_to_watched_attributes?).to be true
      end
    end

    describe "#revert_to" do
      it "raises RevertError when the target version belongs to a different post" do
        post_a = create(:post)
        post_b = create(:post)
        version = post_a.versions.last

        expect { post_b.revert_to(version) }.to raise_error(Post::RevertError)
      end

      it "restores tag_string from the target version" do
        post = create(:post)
        original_tags = post.tag_string
        new_tag = create(:tag)
        post.update!(tag_string: post.tag_string + " #{new_tag.name}")
        old_version = post.versions.first

        post.revert_to(old_version)
        expect(post.tag_string).to eq(original_tags)
      end

      it "restores rating from the target version" do
        post = create(:post, rating: "s")
        post.update!(rating: "e")
        old_version = post.versions.first

        post.revert_to(old_version)
        expect(post.rating).to eq("s")
      end
    end

    describe "#revert_to!" do
      it "persists the revert" do
        post = create(:post, rating: "s")
        post.update!(rating: "e")
        old_version = post.versions.first

        post.revert_to!(old_version)
        expect(post.reload.rating).to eq("s")
      end
    end
  end
end
