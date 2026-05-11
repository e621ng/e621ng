# frozen_string_literal: true

require "rails_helper"

RSpec.describe FavoriteManager do
  include_context "as member"

  let(:user) { create(:user) }
  let(:post) { create(:post) }

  describe ".add!" do
    it "creates a Favorite record" do
      expect { FavoriteManager.add!(user: user, post: post) }
        .to change(Favorite, :count).by(1)
    end

    it "adds the user to the post fav_string" do
      FavoriteManager.add!(user: user, post: post)
      expect(post.reload.fav_string).to include("fav:#{user.id}")
    end

    it "increments post fav_count" do
      expect { FavoriteManager.add!(user: user, post: post) }
        .to change { post.reload.fav_count }.by(1)
    end

    it "increments user favorite_count" do
      expect { FavoriteManager.add!(user: user, post: post) }
        .to change { user.reload.favorite_count }.by(1)
    end

    describe "favorite limit" do
      before do
        allow(user).to receive_messages(favorite_limit: 0, favorite_count: 0)
      end

      it "raises Favorite::Error when the user is at their limit" do
        expect { FavoriteManager.add!(user: user, post: post) }
          .to raise_error(Favorite::Error, /only keep up to/)
      end

      it "bypasses the limit when force: true" do
        expect { FavoriteManager.add!(user: user, post: post, force: true) }
          .not_to raise_error
      end
    end

    describe "duplicate favorite" do
      before { FavoriteManager.add!(user: user, post: post) }

      it "raises Favorite::Error when the user has already favorited the post" do
        expect { FavoriteManager.add!(user: user, post: post) }
          .to raise_error(Favorite::Error, "You have already favorited this post")
      end

      it "returns silently when force: true and the post is already favorited" do
        expect { FavoriteManager.add!(user: user, post: post, force: true) }
          .not_to raise_error
      end
    end

    describe "post save failure" do
      it "raises Favorite::Error when post.save returns false" do
        allow(post).to receive(:save).and_return(false)
        expect { FavoriteManager.add!(user: user, post: post) }
          .to raise_error(Favorite::Error, /Failed to update post/)
      end
    end

    describe "orphaned Favorite record" do
      before do
        # Insert the Favorite row directly, leaving fav_string untouched.
        # This simulates legacy data where the DB record exists but the
        # denormalized fav_string was never updated.
        Favorite.create!(user_id: user.id, post_id: post.id)
      end

      it "repairs the fav_string without raising" do
        expect { FavoriteManager.add!(user: user, post: post) }.not_to raise_error
      end

      it "adds the user to the post fav_string" do
        FavoriteManager.add!(user: user, post: post)
        expect(post.reload.fav_string).to include("fav:#{user.id}")
      end
    end
  end

  describe ".remove!" do
    before { FavoriteManager.add!(user: user, post: post) }

    it "destroys the Favorite record" do
      expect { FavoriteManager.remove!(user: user, post: post) }
        .to change(Favorite, :count).by(-1)
    end

    it "removes the user from the post fav_string" do
      FavoriteManager.remove!(user: user, post: post)
      expect(post.reload.fav_string).not_to include("fav:#{user.id}")
    end

    it "decrements post fav_count" do
      expect { FavoriteManager.remove!(user: user, post: post) }
        .to change { post.reload.fav_count }.by(-1)
    end

    it "decrements user favorite_count" do
      expect { FavoriteManager.remove!(user: user, post: post) }
        .to change { user.reload.favorite_count }.by(-1)
    end

    it "is a no-op when the user has not favorited the post" do
      other = create(:user)
      expect { FavoriteManager.remove!(user: other, post: post) }
        .not_to change(Favorite, :count)
    end

    describe "post save failure" do
      it "raises Favorite::Error when post.save returns false" do
        allow(post).to receive(:save).and_return(false)
        expect { FavoriteManager.remove!(user: user, post: post) }
          .to raise_error(Favorite::Error, /Failed to update post/)
      end
    end
  end
end
