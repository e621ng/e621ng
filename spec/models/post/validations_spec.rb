# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "validations" do
    describe "md5 uniqueness" do
      it "is invalid on create when another post has the same md5" do
        existing = create(:post)
        duplicate = build(:post, md5: existing.md5)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:md5]).to be_present
      end

      it "includes the duplicate post id in the error message" do
        existing = create(:post)
        duplicate = build(:post, md5: existing.md5)
        duplicate.valid?
        expect(duplicate.errors[:md5].first).to include(existing.id.to_s)
      end

      it "is valid on update even when md5 is unchanged" do
        post = create(:post)
        post.update_columns(description: "")
        post.description = "new description"
        expect(post).to be_valid
      end
    end

    describe "rating" do
      %w[s q e].each do |valid_rating|
        it "is valid with rating '#{valid_rating}'" do
          expect(build(:post, rating: valid_rating)).to be_valid
        end
      end

      it "is invalid with an unrecognized rating" do
        post = build(:post, rating: "x")
        expect(post).not_to be_valid
        expect(post.errors[:rating]).to be_present
      end
    end

    describe "bg_color" do
      it "is valid when nil" do
        expect(build(:post, bg_color: nil)).to be_valid
      end

      it "is valid with a 6-character hex string" do
        expect(build(:post, bg_color: "ff0000")).to be_valid
      end

      it "is valid with uppercase hex digits" do
        expect(build(:post, bg_color: "FF0000")).to be_valid
      end

      it "is invalid with a hash-prefixed value" do
        post = build(:post, bg_color: "#ff0000")
        expect(post).not_to be_valid
        expect(post.errors[:bg_color]).to be_present
      end

      it "is invalid with a color name" do
        post = build(:post, bg_color: "red")
        expect(post).not_to be_valid
        expect(post.errors[:bg_color]).to be_present
      end

      it "is invalid with fewer than 6 hex digits" do
        post = build(:post, bg_color: "fffff")
        expect(post).not_to be_valid
        expect(post.errors[:bg_color]).to be_present
      end
    end

    describe "description length" do
      it "is invalid when description exceeds the maximum on a new post" do
        post = build(:post, description: "a" * (Danbooru.config.post_descr_max_size + 1))
        expect(post).not_to be_valid
        expect(post.errors[:description]).to be_present
      end

      it "is valid at exactly the maximum length" do
        post = build(:post, description: "a" * Danbooru.config.post_descr_max_size)
        expect(post).to be_valid
      end

      it "is not re-checked when description is unchanged on update" do
        # Use update_columns to bypass callbacks and plant an oversized description
        post = create(:post)
        post.update_columns(description: "a" * (Danbooru.config.post_descr_max_size + 1))
        post.reload

        # Changing an unrelated attribute must not trigger the description length check
        post.rating = "q"
        expect(post).to be_valid
      end
    end

    describe "post_is_not_its_own_parent" do
      it "is invalid when parent_id equals the post's own id" do
        post = create(:post)
        post.parent_id = post.id
        expect(post).not_to be_valid
        expect(post.errors[:base]).to include("Post cannot have itself as a parent")
      end

      it "does not apply to new records" do
        # A new record has no id yet, so self-parenting cannot occur
        post = build(:post)
        post.parent_id = 0
        expect(post).to be_valid
      end
    end

    describe "updater_can_change_rating" do
      it "is invalid when rating changes on a rating-locked post" do
        post = create(:rating_locked_post, rating: "s")
        post.rating = "e"
        expect(post).not_to be_valid
        expect(post.errors[:rating]).to be_present
      end

      it "is valid when the rating lock is being set and rating changes in the same update" do
        post = create(:post, rating: "s", is_rating_locked: false)
        post.assign_attributes(rating: "e", is_rating_locked: true)
        expect(post).to be_valid
      end

      it "is valid when rating is unchanged on a locked post" do
        post = create(:rating_locked_post, rating: "s")
        post.rating = "s"
        expect(post).to be_valid
      end
    end
  end
end
