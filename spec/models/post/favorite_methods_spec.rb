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
  end
end
