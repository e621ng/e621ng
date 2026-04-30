# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "ValidationMethods" do
    describe "added_tags_are_valid" do
      describe "invalid tag warning" do
        it "adds a warning when an invalid-category tag is added" do
          invalid_tag = create(:invalid_tag)
          post = create(:post)
          post.tag_string = "#{post.tag_string} #{invalid_tag.name}"
          post.valid?
          expect(post.warnings[:base].join).to match(/invalid tag/)
        end

        it "names the offending tag in the warning" do
          invalid_tag = create(:invalid_tag)
          post = create(:post)
          post.tag_string = "#{post.tag_string} #{invalid_tag.name}"
          post.valid?
          expect(post.warnings[:base].join).to include(invalid_tag.name)
        end
      end

      describe "repopulated tag warning" do
        it "warns when a zero-post non-general/non-meta tag older than 10 seconds is added" do
          # A copyright tag with no posts, created in the past
          old_tag = create(:tag, category: Tag.categories.copyright, post_count: 0)
          old_tag.update_columns(created_at: 1.minute.ago)

          post = create(:post)
          post.tag_string = "#{post.tag_string} #{old_tag.name}"
          post.valid?
          expect(post.warnings[:base].join).to match(/Repopulated/)
        end

        it "does not warn for a freshly created tag" do
          fresh_tag = create(:tag, category: Tag.categories.copyright, post_count: 0)
          # created_at is just now, within the 10-second window

          post = create(:post)
          post.tag_string = "#{post.tag_string} #{fresh_tag.name}"
          post.valid?
          expect(post.warnings[:base].join).not_to match(/Repopulated/)
        end
      end
    end

    describe "removed_tags_are_valid" do
      it "warns when a locked tag could not be removed" do
        post = create(:post)
        locked_tag_name = post.tag_array.first
        post.update_columns(locked_tags: locked_tag_name)
        post.reload

        # Try to remove the locked tag via tag_string_diff
        post.tag_string_diff = "-#{locked_tag_name}"
        post.valid?
        expect(post.warnings[:base].join).to match(/could not be removed/)
      end
    end
  end
end
