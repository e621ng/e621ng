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

    describe "#fav_string (lazy load)" do
      it "is excluded from the model's attribute set" do
        post = create(:post)
        fresh = Post.find(post.id)
        expect(fresh.has_attribute?(:fav_string)).to be false
      end

      it "lazy-loads the column on first read" do
        post = create(:post)
        post.write_fav_string!("fav:42", 1)
        fresh = Post.find(post.id)
        expect(fresh.fav_string).to eq("fav:42")
      end

      it "returns empty string for a brand-new record" do
        expect(Post.new.fav_string).to eq("")
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

    describe "#append_user_to_fav_string" do
      it "adds a fav: entry for the user" do
        user = create(:user)
        post = create(:post)
        post.append_user_to_fav_string(user.id)
        expect(post.fav_string).to include("fav:#{user.id}")
      end

      it "increments fav_count" do
        user = create(:user)
        post = create(:post)
        post.append_user_to_fav_string(user.id)
        expect(post.fav_count).to eq(1)
      end

      it "does not add the same user twice" do
        user = create(:user)
        post = create(:post)
        post.write_fav_string!("fav:#{user.id}", 1)
        post.append_user_to_fav_string(user.id)
        expect(post.fav_string.scan("fav:#{user.id}").size).to eq(1)
        expect(post.fav_count).to eq(1)
      end
    end

    describe "#delete_user_from_fav_string" do
      it "removes the fav: entry for the user" do
        user = create(:user)
        post = create(:post)
        post.write_fav_string!("fav:#{user.id}", 1)
        post.delete_user_from_fav_string(user.id)
        expect(post.fav_string).not_to include("fav:#{user.id}")
      end

      it "decrements fav_count" do
        user = create(:user)
        post = create(:post)
        post.write_fav_string!("fav:#{user.id}", 1)
        post.delete_user_from_fav_string(user.id)
        expect(post.fav_count).to eq(0)
      end

      it "does nothing when the user is not in fav_string" do
        user = create(:user)
        other = create(:user)
        post = create(:post)
        post.write_fav_string!("fav:#{other.id}", 1)
        post.delete_user_from_fav_string(user.id)
        expect(post.fav_string).to include("fav:#{other.id}")
        expect(post.fav_count).to eq(1)
      end
    end

    describe "#clean_fav_string!" do
      it "removes duplicate fav entries and recalculates fav_count" do
        user = create(:user)
        post = create(:post)
        post.write_fav_string!("fav:#{user.id} fav:#{user.id}", 2)
        post.clean_fav_string!
        expect(post.fav_string.scan("fav:#{user.id}").size).to eq(1)
        expect(post.fav_count).to eq(1)
      end
    end

    describe "#append_user_to_fav_string, large fav_string path (fav_count > 1000)" do
      it "adds the user via regex branch and increments fav_count" do
        large_fav_string = (1..1001).map { |i| "fav:#{i}" }.join(" ")
        post = create(:post)
        post.write_fav_string!(large_fav_string, 1001)
        new_id = 999_999
        post.append_user_to_fav_string(new_id)
        expect(post.fav_string).to include("fav:#{new_id}")
        expect(post.fav_count).to eq(1002)
      end

      it "does not add a duplicate in the large-fav_string path" do
        existing_id = 999_999
        other_ids = (1..1000).map { |i| i }
        large_fav_string = ([existing_id] + other_ids).map { |i| "fav:#{i}" }.join(" ")
        post = create(:post)
        post.write_fav_string!(large_fav_string, 1001)
        post.append_user_to_fav_string(existing_id)
        matches = post.fav_string.scan(/(?:\A| )fav:#{existing_id}(?:\Z| )/)
        expect(matches.size).to eq(1)
        expect(post.fav_count).to eq(1001)
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
