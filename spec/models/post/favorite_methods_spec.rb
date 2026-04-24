# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "FavoriteMethods" do
    describe "#favorited_by?" do
      it "returns true when the user id is in fav_string" do
        user = create(:user)
        post = build(:post, fav_string: "fav:#{user.id}")
        expect(post.favorited_by?(user.id)).to be true
      end

      it "returns false when the user id is not in fav_string" do
        user = create(:user)
        post = build(:post, fav_string: "")
        expect(post.favorited_by?(user.id)).to be false
      end

      it "does not false-match partial user ids" do
        # user_id 1 should not match "fav:10"
        post = build(:post, fav_string: "fav:10")
        expect(post.favorited_by?(1)).to be false
      end
    end

    describe "#append_user_to_fav_string" do
      it "adds a fav: entry for the user" do
        user = create(:user)
        post = build(:post, fav_string: "")
        post.append_user_to_fav_string(user.id)
        expect(post.fav_string).to include("fav:#{user.id}")
      end

      it "increments fav_count" do
        user = create(:user)
        post = build(:post, fav_string: "", fav_count: 0)
        post.append_user_to_fav_string(user.id)
        expect(post.fav_count).to eq(1)
      end

      it "does not add the same user twice" do
        user = create(:user)
        post = build(:post, fav_string: "fav:#{user.id}", fav_count: 1)
        post.append_user_to_fav_string(user.id)
        expect(post.fav_string.scan("fav:#{user.id}").size).to eq(1)
        expect(post.fav_count).to eq(1)
      end
    end

    describe "#delete_user_from_fav_string" do
      it "removes the fav: entry for the user" do
        user = create(:user)
        post = build(:post, fav_string: "fav:#{user.id}", fav_count: 1)
        post.delete_user_from_fav_string(user.id)
        expect(post.fav_string).not_to include("fav:#{user.id}")
      end

      it "decrements fav_count" do
        user = create(:user)
        post = build(:post, fav_string: "fav:#{user.id}", fav_count: 1)
        post.delete_user_from_fav_string(user.id)
        expect(post.fav_count).to eq(0)
      end

      it "does nothing when the user is not in fav_string" do
        user = create(:user)
        other = create(:user)
        post = build(:post, fav_string: "fav:#{other.id}", fav_count: 1)
        post.delete_user_from_fav_string(user.id)
        expect(post.fav_string).to include("fav:#{other.id}")
        expect(post.fav_count).to eq(1)
      end
    end

    describe "#clean_fav_string!" do
      it "removes duplicate fav entries and recalculates fav_count" do
        user = create(:user)
        post = build(:post, fav_string: "fav:#{user.id} fav:#{user.id}", fav_count: 2)
        post.clean_fav_string!
        expect(post.fav_string.scan("fav:#{user.id}").size).to eq(1)
        expect(post.fav_count).to eq(1)
      end
    end

    describe "#append_user_to_fav_string — large fav_string path (fav_count > 1000)" do
      it "adds the user via regex branch and increments fav_count" do
        create(:user)
        # Build a fav_string with 1001 fake entries
        large_fav_string = (1..1001).map { |i| "fav:#{i}" }.join(" ")
        post = build(:post, fav_string: large_fav_string, fav_count: 1001)
        # Append a new user that is definitely not in the string
        new_id = 999_999
        post.append_user_to_fav_string(new_id)
        expect(post.fav_string).to include("fav:#{new_id}")
        expect(post.fav_count).to eq(1002)
      end

      it "does not add a duplicate in the large-fav_string path" do
        existing_id = 999_999
        other_ids = (1..1000).map { |i| i }
        large_fav_string = ([existing_id] + other_ids).map { |i| "fav:#{i}" }.join(" ")
        post = build(:post, fav_string: large_fav_string, fav_count: 1001)
        post.append_user_to_fav_string(existing_id)
        # Count exact occurrences using word-boundary regex (same as the model uses)
        matches = post.fav_string.scan(/(?:\A| )fav:#{existing_id}(?:\Z| )/)
        expect(matches.size).to eq(1)
        expect(post.fav_count).to eq(1001)
      end
    end

    describe "#favorited_users" do
      it "returns User objects for ids in fav_string, preserving order" do
        user1 = create(:user)
        user2 = create(:user)
        post = create(:post)
        post.update_columns(fav_string: "fav:#{user1.id} fav:#{user2.id}")
        result = post.favorited_users
        expect(result.map(&:id)).to eq([user1.id, user2.id])
      end

      it "excludes users with hide_favorites? set when viewed as a member" do
        visible_user = create(:user)
        hidden_user  = create(:user)
        privacy_flag = User.flag_value_for("enable_privacy_mode")
        hidden_user.update_columns(bit_prefs: privacy_flag)
        post = create(:post)
        post.update_columns(fav_string: "fav:#{visible_user.id} fav:#{hidden_user.id}")

        # Switch to a member (non-moderator) so hide_favorites? can return true
        viewer = create(:user)
        CurrentUser.user    = viewer
        CurrentUser.ip_addr = "127.0.0.1"

        result = post.favorited_users
        expect(result.map(&:id)).to include(visible_user.id)
        expect(result.map(&:id)).not_to include(hidden_user.id)
      end
    end
  end
end
