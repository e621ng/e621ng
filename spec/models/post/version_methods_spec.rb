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
