# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "FavoriteMethods" do
    describe "#favorited_by?" do
      it "returns true when the user has favorited the post" do
        user = create(:user)
        post = create(:post)
        Favorite.create!(user_id: user.id, post_id: post.id)
        expect(post.favorited_by?(user.id)).to be true
      end

      it "returns false when the user has not favorited the post" do
        user = create(:user)
        post = create(:post)
        expect(post.favorited_by?(user.id)).to be false
      end

      it "returns false for a blank user id" do
        post = create(:post)
        expect(post.favorited_by?(nil)).to be false
      end

      it "caches the DB result so a second call does not hit the database" do
        user = create(:user)
        post = create(:post)
        post.favorited_by?(user.id) # primes cache
        allow(Favorite).to receive(:exists?)
        post.favorited_by?(user.id)
        expect(Favorite).not_to have_received(:exists?)
      end

      it "uses the preloaded cache instead of hitting the database" do
        post = create(:post)
        post.preset_favorited_status(42, true)
        allow(Favorite).to receive(:exists?)
        expect(post.favorited_by?(42)).to be true
        expect(Favorite).not_to have_received(:exists?)
      end

      it "uses the preloaded false value instead of hitting the database" do
        post = create(:post)
        post.preset_favorited_status(42, false)
        allow(Favorite).to receive(:exists?)
        expect(post.favorited_by?(42)).to be false
        expect(Favorite).not_to have_received(:exists?)
      end
    end

    describe ".preload_favorited_status!" do
      it "marks favorited posts as favorited and others as not" do
        user = create(:user)
        favorited = create(:post)
        other = create(:post)
        Favorite.create!(user_id: user.id, post_id: favorited.id)

        Post.preload_favorited_status!([favorited, other], user.id)
        expect(favorited.favorited_by?(user.id)).to be true
        expect(other.favorited_by?(user.id)).to be false
      end

      it "is a no-op for a blank user id" do
        post = create(:post)
        expect { Post.preload_favorited_status!([post], nil) }.not_to(change { post.instance_variable_get(:@favorited_status_cache) })
      end

      it "is a no-op for an empty post list" do
        expect { Post.preload_favorited_status!([], 1) }.not_to raise_error
      end

      it "accepts a single post" do
        user = create(:user)
        post = create(:post)
        Favorite.create!(user_id: user.id, post_id: post.id)
        Post.preload_favorited_status!(post, user.id)
        expect(post.favorited_by?(user.id)).to be true
      end
    end

    describe "#refresh_fav_count" do
      it "sets fav_count to the number of favorites for the post" do
        user_a = create(:user)
        user_b = create(:user)
        post = create(:post)
        Favorite.create!(user_id: user_a.id, post_id: post.id)
        Favorite.create!(user_id: user_b.id, post_id: post.id)
        post.refresh_fav_count
        expect(post.fav_count).to eq(2)
      end

      it "marks fav_count as changed so a following save persists it" do
        user = create(:user)
        post = create(:post)
        Favorite.create!(user_id: user.id, post_id: post.id)
        post.refresh_fav_count
        expect(post.fav_count_changed?).to be true
      end
    end

    describe ".preload_stats!" do
      it "preloads both favorited status and vote for the collection" do
        user = create(:user)
        post = create(:post)
        Favorite.create!(user_id: user.id, post_id: post.id)
        PostVote.create!(post: post, user: user, score: 1)

        Post.preload_stats!([post], user)
        allow(Favorite).to receive(:exists?)
        allow(PostVote).to receive(:where)
        expect(post.favorited_by?(user.id)).to be true
        expect(post.vote_by(user.id)).to eq(1)
        expect(Favorite).not_to have_received(:exists?)
        expect(PostVote).not_to have_received(:where)
      end

      it "is a no-op for an anonymous user" do
        post = create(:post)
        expect { Post.preload_stats!([post], User.anonymous) }.not_to(change { post.instance_variable_get(:@favorited_status_cache) })
      end

      it "is a no-op for a nil user" do
        post = create(:post)
        expect { Post.preload_stats!([post], nil) }.not_to raise_error
      end
    end

    describe "#favorited_users" do
      it "returns User objects for users who favorited the post, ordered by when they favorited" do
        user1 = create(:user)
        user2 = create(:user)
        post = create(:post)
        Favorite.create!(user_id: user1.id, post_id: post.id)
        Favorite.create!(user_id: user2.id, post_id: post.id)
        result = post.favorited_users
        expect(result.map(&:id)).to eq([user1.id, user2.id])
      end

      it "excludes users with hide_favorites? set when viewed as a member" do
        visible_user = create(:user)
        hidden_user  = create(:user)
        privacy_flag = User.flag_value_for("enable_privacy_mode")
        hidden_user.update_columns(bit_prefs: privacy_flag)
        post = create(:post)
        Favorite.create!(user_id: visible_user.id, post_id: post.id)
        Favorite.create!(user_id: hidden_user.id, post_id: post.id)

        # Switch to a member (non-moderator) so hide_favorites? can return true
        viewer = create(:user)
        CurrentUser.user    = viewer
        CurrentUser.ip_addr = "127.0.0.1"

        result = post.favorited_users
        expect(result.map(&:id)).to include(visible_user.id)
        expect(result.map(&:id)).not_to include(hidden_user.id)
      end
    end

    describe "#remove_from_favorites" do
      it "deletes all Favorite records for the post" do
        user_a = create(:user)
        user_b = create(:user)
        post = create(:post)
        Favorite.create!(user_id: user_a.id, post_id: post.id)
        Favorite.create!(user_id: user_b.id, post_id: post.id)
        expect { post.remove_from_favorites }.to change { Favorite.where(post_id: post.id).count }.from(2).to(0)
      end

      it "decrements favorite_count for each user who had favorited the post" do
        user = create(:user)
        post = create(:post)
        Favorite.create!(user_id: user.id, post_id: post.id)
        expect { post.remove_from_favorites }.to change { user.user_status.reload.favorite_count }.by(-1)
      end

      it "does nothing when no favorites exist" do
        post = create(:post)
        expect { post.remove_from_favorites }.not_to raise_error
      end
    end
  end
end
