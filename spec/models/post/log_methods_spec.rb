# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "PostEventMethods" do
    describe "#create_post_events" do
      describe "rating lock" do
        it "creates a rating_locked PostEvent when is_rating_locked is set to true" do
          post = create(:post, is_rating_locked: false)
          post.update!(is_rating_locked: true)
          expect(PostEvent.where(post_id: post.id, action: PostEvent.actions[:rating_locked])).to exist
        end

        it "creates a rating_unlocked PostEvent when is_rating_locked is cleared" do
          post = create(:rating_locked_post)
          post.update!(is_rating_locked: false)
          expect(PostEvent.where(post_id: post.id, action: PostEvent.actions[:rating_unlocked])).to exist
        end
      end

      describe "status lock" do
        it "creates a status_locked PostEvent when is_status_locked is set to true" do
          post = create(:post, is_status_locked: false)
          post.update!(is_status_locked: true)
          expect(PostEvent.where(post_id: post.id, action: PostEvent.actions[:status_locked])).to exist
        end

        it "creates a status_unlocked PostEvent when is_status_locked is cleared" do
          post = create(:status_locked_post)
          post.update!(is_status_locked: false)
          expect(PostEvent.where(post_id: post.id, action: PostEvent.actions[:status_unlocked])).to exist
        end
      end

      describe "note lock" do
        it "creates a note_locked PostEvent when is_note_locked is set to true" do
          post = create(:post, is_note_locked: false)
          post.update!(is_note_locked: true)
          expect(PostEvent.where(post_id: post.id, action: PostEvent.actions[:note_locked])).to exist
        end

        it "creates a note_unlocked PostEvent when is_note_locked is cleared" do
          post = create(:note_locked_post)
          post.update!(is_note_locked: false)
          expect(PostEvent.where(post_id: post.id, action: PostEvent.actions[:note_unlocked])).to exist
        end
      end

      describe "comment lock" do
        it "creates a comment_locked PostEvent when is_comment_locked is set to true" do
          post = create(:post, is_comment_locked: false)
          post.update!(is_comment_locked: true)
          expect(PostEvent.where(post_id: post.id, action: PostEvent.actions[:comment_locked])).to exist
        end
      end

      describe "background color change" do
        it "creates a changed_bg_color PostEvent when bg_color changes" do
          post = create(:post, bg_color: nil)
          post.update!(bg_color: "ff0000")
          expect(PostEvent.where(post_id: post.id, action: PostEvent.actions[:changed_bg_color])).to exist
        end
      end

      it "does not create a PostEvent when only score changes" do
        post = create(:post)
        initial_count = PostEvent.where(post_id: post.id).count
        post.update_columns(score: 99)
        expect(PostEvent.where(post_id: post.id).count).to eq(initial_count)
      end

      describe "comment disabled" do
        it "creates a comment_disabled PostEvent when is_comment_disabled is set to true" do
          post = create(:post, is_comment_disabled: false)
          post.update!(is_comment_disabled: true)
          expect(PostEvent.where(post_id: post.id, action: PostEvent.actions[:comment_disabled])).to exist
        end

        it "creates a comment_enabled PostEvent when is_comment_disabled is cleared" do
          post = create(:post)
          post.update_columns(is_comment_disabled: true)
          post.reload.update!(is_comment_disabled: false)
          expect(PostEvent.where(post_id: post.id, action: PostEvent.actions[:comment_enabled])).to exist
        end
      end
    end
  end
end
