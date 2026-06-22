# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "UploaderMethods" do
    describe "#previous_version_uploaders" do
      it "returns the deduplicated list of previous replacement uploaders" do
        post = create(:post)
        user1 = create(:user)
        user2 = create(:user)
        replacement0 = create(:original_post_replacement, post: post, creator: post.uploader)
        replacement1 = create(:approved_post_replacement, post: post, creator: user1)
        replacement2 = create(:approved_post_replacement, post: post, creator: user2)
        replacement3 = create(:approved_post_replacement, post: post, creator: user1)
        expect(replacement0.creator).to eq(post.uploader)
        expect(replacement1.creator).to eq(user1)
        expect(replacement2.creator).to eq(user2)
        expect(replacement3.creator).to eq(user1)
        expect(post.previous_version_uploaders).to eq([user1, user2])
      end

      it "returns empty if the post was never replaced" do
        post = create(:post)
        expect(post.previous_version_uploaders).to eq([])
      end

      it "doesn't return pending or rejected replacement uploaders" do
        post = create(:post)
        user1 = create(:user)
        user2 = create(:user)
        user3 = create(:user)
        replacement0 = create(:original_post_replacement, post: post, creator: post.uploader)
        replacement1 = create(:approved_post_replacement, post: post, creator: user1)
        replacement2 = create(:pending_post_replacement, post: post, creator: user2)
        replacement3 = create(:rejected_post_replacement, post: post, creator: user3)
        expect(replacement0.creator).to eq(post.uploader)
        expect(replacement1.creator).to eq(user1)
        expect(replacement2.creator).to eq(user2)
        expect(replacement3.creator).to eq(user3)
        expect(post.previous_version_uploaders).to eq([user1])
      end
    end

    describe "#reowner!" do
      let(:post) { create(:post) }
      let(:new_owner) { create(:user) }
      let!(:old_owner) { post.uploader }
      let(:other_user) { create(:user) }

      context "when the user is an admin" do
        it "allows assigning any user as the new owner" do
          post.reowner!(new_owner)
          expect(post.reload.uploader_id).to eq(new_owner.id)
        end

        it "raises a PrivilegeError when reownering versions" do
          expect do
            post.reowner!(new_owner, reowner_versions: true)
          end.to raise_error(User::PrivilegeError)
        end

        it "raises a PrivilegeError when disabling post events" do
          expect do
            post.reowner!(new_owner, post_events: false)
          end.to raise_error(User::PrivilegeError)
        end
      end

      context "when the user is not a janitor" do
        include_context "as member"

        it "raises a PrivilegeError when assigning a user who is a previous version uploader" do
          create(:approved_post_replacement, post: post, creator: new_owner)
          expect do
            post.reowner!(new_owner)
          end.to raise_error(User::PrivilegeError)
        end

        it "raises a PrivilegeError when assigning a user who is not a previous uploader" do
          expect do
            post.reowner!(new_owner)
          end.to raise_error(User::PrivilegeError)
        end
      end

      context "when the user is a janitor" do
        include_context "as janitor"

        it "allows assigning a user who is a previous version uploader" do
          create(:approved_post_replacement, post: post, creator: new_owner)
          post.reowner!(new_owner)
          expect(post.reload.uploader_id).to eq(new_owner.id)
        end

        it "raises a PrivilegeError when assigning a user who is not a previous uploader" do
          expect do
            post.reowner!(new_owner)
          end.to raise_error(User::PrivilegeError)
        end
      end

      context "when the user is a BD admin" do
        include_context "as bd admin"

        describe "reowner_versions parameter" do
          let!(:version1) do # rubocop:disable RSpec/IndexedLet
            create(:post_version, post: post).tap { |v| v.update_column(:updater_id, old_owner.id) }
          end
          let!(:version2) do # rubocop:disable RSpec/IndexedLet
            create(:post_version, post: post).tap { |v| v.update_column(:updater_id, old_owner.id) }
          end
          let!(:version3) do # rubocop:disable RSpec/IndexedLet
            create(:post_version, post: post).tap { |v| v.update_column(:updater_id, other_user.id) }
          end

          it "updates the updater_id on previous versions when true" do
            post.reowner!(new_owner, reowner_versions: true)
            expect(version1.reload.updater_id).to eq(new_owner.id)
            expect(version2.reload.updater_id).to eq(new_owner.id)
            expect(version3.reload.updater_id).to eq(other_user.id)
          end

          it "does not update previous versions when false" do
            post.reowner!(new_owner, reowner_versions: false)
            expect(version1.reload.updater_id).to eq(old_owner.id)
            expect(version2.reload.updater_id).to eq(old_owner.id)
            expect(version3.reload.updater_id).to eq(other_user.id)
          end
        end

        describe "post_events parameter" do
          it "creates an owner_changed post event by default (true)" do
            expect do
              post.reowner!(new_owner)
            end.to change { PostEvent.where(action: "owner_changed", post_id: post.id).count }.by(1)

            event = PostEvent.last
            expect(event.extra_data).to include("old_owner" => old_owner.id, "new_owner" => new_owner.id)
          end

          it "does not create a post event when false" do
            expect do
              post.reowner!(new_owner, post_events: false)
            end.not_to change(PostEvent, :count)
          end

          it "does not create a post event when the old and new owners are the same" do
            expect do
              post.reowner!(old_owner, post_events: true)
            end.not_to change(PostEvent, :count)
          end
        end

        it "skips versioning the post update itself" do
          expect do
            post.reowner!(new_owner, post_events: false)
          end.not_to(change { post.versions.count })
        end
      end
    end
  end
end
