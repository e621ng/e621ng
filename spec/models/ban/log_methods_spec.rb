# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          Ban::ModAction Logging                             #
# --------------------------------------------------------------------------- #

RSpec.describe Ban do
  let(:moderator)    { create(:moderator_user) }
  let(:subject_user) { create(:user) }

  before { CurrentUser.user = moderator }
  after  { CurrentUser.user = nil }

  describe "log methods" do
    # -------------------------------------------------------------------------
    # #create_ban_mod_action (via after_create)
    # -------------------------------------------------------------------------
    describe "#create_ban_mod_action" do
      it "logs a user_ban action when a ban is created" do
        ban = create(:ban, user: subject_user, banner: moderator, duration: 30, reason: "test reason")
        log = ModAction.where(action: "user_ban").last

        expect(log).to be_present
        # log[:values] accesses the raw jsonb column directly, bypassing level-based
        # filtering in ModAction#values, so assertions are role-agnostic.
        expect(log[:values]).to include(
          "user_id" => subject_user.id,
          "reason" => "test reason",
          "duration" => ban.duration,
        )
      end
    end

    # -------------------------------------------------------------------------
    # #create_ban_update_mod_action (via after_update)
    # -------------------------------------------------------------------------
    describe "#create_ban_update_mod_action" do
      it "logs a user_ban_update action when a ban is updated" do
        ban = create(:ban, user: subject_user, banner: moderator, duration: 30, reason: "original reason")

        ban.update!(reason: "updated reason", duration: 60)
        log = ModAction.where(action: "user_ban_update").last

        expect(log).to be_present
        expect(log[:values]).to include(
          "user_id" => subject_user.id,
          "ban_id" => ban.id,
          "reason" => "updated reason",
          "reason_was" => "original reason",
        )
        expect(log[:values]["expires_at_was"]).to be_present
      end
    end

    # -------------------------------------------------------------------------
    # #create_unban_mod_action (via after_destroy)
    # -------------------------------------------------------------------------
    describe "#create_unban_mod_action" do
      it "logs a user_unban action when a ban is destroyed" do
        ban = create(:ban, user: subject_user, banner: moderator)
        ban.destroy!
        log = ModAction.where(action: "user_unban").last

        expect(log).to be_present
        expect(log[:values]).to include("user_id" => subject_user.id)
      end
    end
  end
end
