# frozen_string_literal: true

require "rails_helper"

RSpec.describe FlushFavoritesJob do
  include_context "as admin"

  def perform(user_id = CurrentUser.id)
    described_class.perform_now(user_id)
  end

  # Creates a Favorite and keeps post.fav_string / fav_count consistent.
  # Favorite.create! fires user_status_counter → UserStatus.favorite_count++
  def add_favorite(post, user)
    Favorite.create!(post_id: post.id, user_id: user.id)
    post.update_columns(
      fav_string: "#{post.fav_string} fav:#{user.id}".strip,
      fav_count:  post.fav_count + 1,
    )
  end

  describe "#perform" do
    context "when the user does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect { perform(0) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the user has no favorites" do
      it "does not delete any Favorite records" do
        expect { perform }.not_to change(Favorite, :count)
      end

      it "does not raise an error" do
        expect { perform }.not_to raise_error
      end
    end

    context "when the user has one favorite" do
      let(:post) { create(:post) }

      before { add_favorite(post, CurrentUser.user) }

      it "deletes the Favorite record" do
        expect { perform }.to change(Favorite, :count).by(-1)
      end

      it "removes the user from the post fav_string" do
        perform
        expect(post.reload.fav_string).not_to include("fav:#{CurrentUser.id}")
      end

      it "decrements the post fav_count to 0" do
        perform
        expect(post.reload.fav_count).to eq(0)
      end

      it "decrements the user favorite_count to 0" do
        perform
        expect(CurrentUser.user.user_status.reload.favorite_count).to eq(0)
      end
    end

    context "when the user has multiple favorites" do
      let(:post_a) { create(:post) }
      let(:post_b) { create(:post) }
      let(:post_c) { create(:post) }

      before do
        add_favorite(post_a, CurrentUser.user)
        add_favorite(post_b, CurrentUser.user)
        add_favorite(post_c, CurrentUser.user)
      end

      it "deletes all Favorite records for the user" do
        expect { perform }.to change(Favorite, :count).by(-3)
        expect(Favorite.for_user(CurrentUser.id)).to be_empty
      end

      it "decrements the user favorite_count to 0" do
        perform
        expect(CurrentUser.user.user_status.reload.favorite_count).to eq(0)
      end

      it "clears fav_string on all favorited posts" do
        perform
        [post_a, post_b, post_c].each do |post|
          expect(post.reload.fav_string).not_to include("fav:#{CurrentUser.id}")
        end
      end

      it "sets fav_count to 0 on all favorited posts" do
        perform
        [post_a, post_b, post_c].each do |post|
          expect(post.reload.fav_count).to eq(0)
        end
      end
    end

    context "when another user also has favorites on the same post" do
      let(:target_user) { CurrentUser.user }
      let(:other_user)  { create(:user) }
      let(:post)        { create(:post) }

      before do
        add_favorite(post, target_user)
        add_favorite(post, other_user)
      end

      it "removes only the target user's Favorite" do
        perform(target_user.id)
        expect(Favorite.for_user(target_user.id)).to be_empty
      end

      it "leaves the other user's Favorite intact" do
        perform(target_user.id)
        expect(Favorite.find_by(post_id: post.id, user_id: other_user.id)).to be_present
      end

      it "does not change the other user's favorite_count" do
        perform(target_user.id)
        expect(other_user.user_status.reload.favorite_count).to eq(1)
      end
    end

    context "when FavoriteManager raises SerializationFailure" do
      let(:post) { create(:post) }

      before { add_favorite(post, CurrentUser.user) }

      context "on the first attempt only" do
        before do
          call_count = 0
          allow(FavoriteManager).to receive(:remove!).and_wrap_original do |original, **kwargs|
            call_count += 1
            raise ActiveRecord::SerializationFailure if call_count == 1

            original.call(**kwargs)
          end
        end

        it "does not raise an error" do
          expect { perform }.not_to raise_error
        end

        it "eventually removes the Favorite" do
          perform
          expect(Favorite.for_user(CurrentUser.id)).to be_empty
        end
      end

      context "on every attempt (all 5 exhausted)" do
        before do
          allow(FavoriteManager).to receive(:remove!).and_raise(ActiveRecord::SerializationFailure)
        end

        it "does not raise an error" do
          expect { perform }.not_to raise_error
        end

        it "retries exactly 5 times" do
          perform
          expect(FavoriteManager).to have_received(:remove!).exactly(5).times
        end

        it "leaves the Favorite record in place" do
          perform
          expect(Favorite.for_user(CurrentUser.id)).not_to be_empty
        end
      end
    end
  end
end
