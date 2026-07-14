# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                             User::LevelMethods                              #
# --------------------------------------------------------------------------- #

RSpec.describe User do
  describe "level methods" do
    # -------------------------------------------------------------------------
    # .level_string
    # -------------------------------------------------------------------------
    describe ".level_string" do
      it "returns the level name for a known value" do
        expect(User.level_string(UserLevel::MEMBER)).to eq("Member")
        expect(User.level_string(UserLevel::ADMIN)).to eq("Admin")
      end

      it "returns an empty string for an unknown value" do
        expect(User.level_string(999)).to eq("")
      end
    end

    # -------------------------------------------------------------------------
    # .anonymous
    # -------------------------------------------------------------------------
    describe ".anonymous" do
      subject(:anon) { User.anonymous }

      it "has the anonymous level" do
        expect(anon.level).to eq(UserLevel::ANONYMOUS)
      end

      it "is named Anonymous" do
        expect(anon.name).to eq("Anonymous")
      end

      it "is frozen" do
        expect(anon).to be_frozen
      end

      it "is read-only" do
        expect(anon).to be_readonly
      end
    end

    # -------------------------------------------------------------------------
    # .system
    # -------------------------------------------------------------------------
    describe ".system" do
      before do
        allow(Danbooru.config.custom_configuration).to receive_messages(system_user: "System", system_user_id: nil)
        create(:user, name: "System", level: UserLevel::MODERATOR)
        RequestStore[:system_user] = nil
      end

      after do
        RequestStore[:system_user] = nil
      end

      it "returns the system user" do
        system_user = User.find_by!(name: Danbooru.config.system_user)
        expect(User.system.id).to eq(system_user.id)
      end

      it "returns the system user if ID is set" do
        system_user = User.find_by!(name: Danbooru.config.system_user)
        allow(Danbooru.config.custom_configuration).to receive(:system_user_id).and_return(system_user.id)
        expect(User.system).to eq(system_user)
      end

      it "raises an error if the system user does not exist" do
        allow(Danbooru.config.custom_configuration).to receive(:system_user).and_return("Nonexistent")
        expect { User.system }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "returns the system user if the ID is set but the name is changed" do
        system_user = User.find_by!(name: Danbooru.config.system_user)
        allow(Danbooru.config.custom_configuration).to receive(:system_user_id).and_return(system_user.id)
        system_user.update!(name: "NewName")
        expect(User.system.id).to eq(system_user.id)
      end
    end

    # -------------------------------------------------------------------------
    # #level_string
    # -------------------------------------------------------------------------
    describe "#level_string" do
      it "returns the level name for the user's current level" do
        user = build(:user, level: UserLevel::MEMBER)
        expect(user.level_string).to eq("Member")
      end

      it "returns the level name for a given value, ignoring the user's level" do
        user = build(:user, level: UserLevel::MEMBER)
        expect(user.level_string(UserLevel::ADMIN)).to eq("Admin")
      end
    end

    # -------------------------------------------------------------------------
    # #level_string_was
    # -------------------------------------------------------------------------
    describe "#level_string_was" do
      it "returns the previous level name after a level change" do
        user = create(:user, level: UserLevel::MEMBER)
        user.level = UserLevel::JANITOR
        expect(user.level_string_was).to eq("Member")
      end
    end

    # -------------------------------------------------------------------------
    # #is_logged_in?
    # -------------------------------------------------------------------------
    describe "#is_logged_in?" do
      it "returns false for an anonymous user" do
        expect(User.anonymous.is_logged_in?).to be(false)
      end

      it "returns true for a regular member" do
        user = build(:user)
        expect(user.is_logged_in?).to be(true)
      end

      it "returns true for a blocked user" do
        user = build(:user, level: UserLevel::BLOCKED)
        expect(user.is_logged_in?).to be(true)
      end

      it "returns true for a staff member" do
        user = build(:admin_user)
        expect(user.is_logged_in?).to be(true)
      end
    end

    # -------------------------------------------------------------------------
    # #is_logged_out?
    # -------------------------------------------------------------------------
    describe "#is_logged_out?" do
      it "returns true for an anonymous user" do
        expect(User.anonymous.is_logged_out?).to be(true)
      end

      it "returns false for a regular member" do
        user = build(:user)
        expect(user.is_logged_out?).to be(false)
      end
    end

    # -------------------------------------------------------------------------
    # #is_restricted?
    # -------------------------------------------------------------------------
    describe "#is_restricted?" do
      it "returns true for a hard-banned user" do
        user = build(:user, level: UserLevel::BLOCKED)
        build(:ban, user: user, prevent_login: true)
        expect(user.is_restricted?).to be(true)
      end

      it "returns true for a soft-banned user" do
        user = build(:user, level: UserLevel::BLOCKED)
        build(:ban, user: user, prevent_login: false)
        expect(user.is_restricted?).to be(true)
      end

      it "returns false for a regular member" do
        user = build(:user)
        expect(user.is_restricted?).to be(false)
      end
    end

    # -------------------------------------------------------------------------
    # Dynamic is_<level>? methods
    # -------------------------------------------------------------------------
    describe "dynamic level predicate methods" do
      it "returns true when the user's level meets or exceeds the threshold" do
        user = create(:admin_user)
        expect(user.is_admin?).to be(true)
        expect(user.is_moderator?).to be(true)
        expect(user.is_janitor?).to be(true)
        expect(user.is_staff?).to be(true)
        expect(user.is_member?).to be(true)
      end

      it "returns false when the user's level is below the threshold" do
        user = create(:user)
        expect(user.is_admin?).to be(false)
        expect(user.is_moderator?).to be(false)
        expect(user.is_janitor?).to be(false)
        expect(user.is_staff?).to be(false)
      end

      it "returns false for an unpersisted user" do
        # is_<level>? requires id.present? — build does not persist, so id is nil
        user = build(:admin_user)
        expect(user.is_admin?).to be(false)
      end
    end

    # -------------------------------------------------------------------------
    # #is_approver?
    # -------------------------------------------------------------------------
    describe "#is_approver?" do
      it "returns true when the user has the can_approve_posts flag" do
        user = build(:approver_user)
        expect(user.is_approver?).to be(true)
      end

      it "returns false when the user does not have the can_approve_posts flag" do
        user = build(:user)
        expect(user.is_approver?).to be(false)
      end
    end

    # -------------------------------------------------------------------------
    # #level_css_class
    # -------------------------------------------------------------------------
    describe "#level_css_class" do
      it "returns the parameterized level name prefixed with 'user-'" do
        expect(build(:user, level: UserLevel::MEMBER).level_css_class).to eq("user-member")
        expect(build(:user, level: UserLevel::ADMIN).level_css_class).to eq("user-admin")
      end

      it "hyphenates multi-word level names" do
        expect(build(:user, level: UserLevel::FORMER_STAFF).level_css_class).to eq("user-former-staff")
      end
    end
  end
end
