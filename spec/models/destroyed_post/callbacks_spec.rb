# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       DestroyedPost Callbacks                               #
# --------------------------------------------------------------------------- #

RSpec.describe DestroyedPost do
  let(:admin) { create(:admin_user) }

  before { CurrentUser.user = admin }
  after  { CurrentUser.user = nil }

  describe "callbacks" do
    describe "after_update :log_notify_change, if: :saved_change_to_notify?" do
      let!(:dp) { create(:destroyed_post, notify: true) }

      it "logs :disable_post_notifications when notify flips true → false" do
        expect { dp.update!(notify: false) }.to change(StaffAuditLog, :count).by(1)

        log = StaffAuditLog.last
        expect(log.action).to eq("disable_post_notifications")
        expect(log.values["destroyed_post_id"]).to eq(dp.id)
        expect(log.values["post_id"]).to eq(dp.post_id)
      end

      it "logs :enable_post_notifications when notify flips false → true" do
        dp.update_column(:notify, false)

        expect { dp.update!(notify: true) }.to change(StaffAuditLog, :count).by(1)

        log = StaffAuditLog.last
        expect(log.action).to eq("enable_post_notifications")
        expect(log.values["destroyed_post_id"]).to eq(dp.id)
        expect(log.values["post_id"]).to eq(dp.post_id)
      end

      it "attributes the log entry to the current user" do
        dp.update!(notify: false)
        expect(StaffAuditLog.last.user).to eq(admin)
      end

      it "does not fire when a non-notify field is changed" do
        expect { dp.update!(reason: "updated reason") }.not_to change(StaffAuditLog, :count)
      end
    end
  end
end
