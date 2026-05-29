# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserDeletion do
  include_context "as admin"

  let(:password) { "hexerade" }

  describe "#delete!" do
    context "when deleting own account (admin_deletion: false)" do
      subject(:deletion) { described_class.new(user, password) }

      let(:user) { create(:user) }

      it "renames the user to user_{id}" do
        deletion.delete!
        expect(user.reload.name).to eq("user_#{user.id}")
      end

      it "creates a UserNameChangeRequest recording the rename" do
        original_name = user.name
        expect { deletion.delete! }.to change(UserNameChangeRequest, :count).by(1)
        req = UserNameChangeRequest.last
        expect(req.original_name).to eq(original_name)
        expect(req.desired_name).to eq("user_#{user.id}")
        expect(req.change_reason).to eq("User deletion")
      end

      it "clears email, tags, profile fields, and resets level to MEMBER" do
        deletion.delete!
        user.reload
        expect(user.email).to eq("")
        expect(user.recent_tags).to eq("")
        expect(user.favorite_tags).to eq("")
        expect(user.blacklisted_tags).to eq("")
        expect(user.profile_about).to eq("")
        expect(user.profile_artinfo).to eq("")
        expect(user.custom_style).to eq("")
        expect(user.level).to eq(User::Levels::MEMBER)
      end

      it "invalidates the password hash" do
        deletion.delete!
        user.reload
        expect(user.password_hash).to eq("")
        expect(user.bcrypt_password_hash).to eq("*LK*")
      end

      it "logs a :user_delete ModAction" do
        deletion.delete!
        expect(ModAction.last.action).to eq("user_delete")
        expect(ModAction.last[:values]).to include("user_id" => user.id)
      end

      it "enqueues FlushFavoritesJob with the user's id" do
        expect { deletion.delete! }.to have_enqueued_job(FlushFavoritesJob).with(user.id)
      end

      it "enqueues AvatarCleanupJob with force: true" do
        expect { deletion.delete! }.to have_enqueued_job(AvatarCleanupJob).with(user.id, force: true)
      end
    end

    context "when the user is already named user_{id}" do
      subject(:deletion) { described_class.new(user, password) }

      let(:user) { create(:user) }

      before { user.update_columns(name: "user_#{user.id}") }

      it "does not create a UserNameChangeRequest" do
        expect { deletion.delete! }.not_to change(UserNameChangeRequest, :count)
      end
    end

    context "when admin deletes a member account (admin_deletion: true)" do
      subject(:deletion) { described_class.new(user, nil, admin_deletion: true) }

      let(:user) { create(:user) }

      it "renames the user to user_{id}" do
        deletion.delete!
        expect(user.reload.name).to eq("user_#{user.id}")
      end

      it "logs an :admin_user_delete ModAction" do
        deletion.delete!
        expect(ModAction.last.action).to eq("admin_user_delete")
        expect(ModAction.last[:values]).to include("user_id" => user.id)
      end

      it "creates a UserNameChangeRequest with reason 'Administrative deletion'" do
        deletion.delete!
        expect(UserNameChangeRequest.last.change_reason).to eq("Administrative deletion")
      end

      it "enqueues FlushFavoritesJob" do
        expect { deletion.delete! }.to have_enqueued_job(FlushFavoritesJob).with(user.id)
      end
    end

    context "validation" do
      it "raises ValidationError for a banned user doing self-deletion" do
        user = create(:banned_user)
        expect { described_class.new(user, password).delete! }
          .to raise_error(UserDeletion::ValidationError, /Banned users/)
      end

      it "raises ValidationError when the account is less than one week old" do
        user = create(:user, created_at: 1.day.ago)
        expect { described_class.new(user, password).delete! }
          .to raise_error(UserDeletion::ValidationError, /one week old/)
      end

      it "raises ValidationError when the password is incorrect" do
        user = create(:user)
        expect { described_class.new(user, "wrongpassword").delete! }
          .to raise_error(UserDeletion::ValidationError, /Password is incorrect/)
      end

      it "raises ValidationError for an admin trying to delete their own account" do
        admin = create(:admin_user)
        expect { described_class.new(admin, password).delete! }
          .to raise_error(UserDeletion::ValidationError, /Admins cannot delete/)
      end

      it "raises ValidationError when admin_deletion targets a janitor" do
        staff = create(:janitor_user)
        expect { described_class.new(staff, nil, admin_deletion: true).delete! }
          .to raise_error(UserDeletion::ValidationError, /Staff accounts/)
      end

      it "raises ValidationError when admin_deletion targets a moderator" do
        staff = create(:moderator_user)
        expect { described_class.new(staff, nil, admin_deletion: true).delete! }
          .to raise_error(UserDeletion::ValidationError, /Staff accounts/)
      end

      it "raises ValidationError when admin_deletion targets an admin" do
        admin = create(:admin_user)
        expect { described_class.new(admin, nil, admin_deletion: true).delete! }
          .to raise_error(UserDeletion::ValidationError, /Admins cannot delete/)
      end
    end

    context "name collision" do
      it "falls back to user_{id}_1 when user_{id} is already taken by another user" do
        target = create(:user)
        squatter = create(:user)
        squatter.update_columns(name: "user_#{target.id}")

        described_class.new(target, password).delete!
        expect(target.reload.name).to eq("user_#{target.id}_1")
      end
    end
  end
end
