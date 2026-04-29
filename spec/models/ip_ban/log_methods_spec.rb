# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        IpBan::ModAction Logging                            #
# --------------------------------------------------------------------------- #

RSpec.describe IpBan do
  let(:moderator) { create(:moderator_user) }

  before { CurrentUser.user = moderator }
  after  { CurrentUser.user = nil }

  describe "log methods" do
    # -------------------------------------------------------------------------
    # after_create → ip_ban_create
    # -------------------------------------------------------------------------
    describe "after_create" do
      it "logs an ip_ban_create action when a host address is banned" do
        create(:ip_ban, ip_addr: "1.2.3.4", reason: "spam source")
        log = ModAction.last

        expect(log.action).to eq("ip_ban_create")
        # log[:values] reads the raw jsonb column directly, bypassing the ModAction#values
        # accessor which filters fields based on CurrentUser's level.
        expect(log[:values]).to include(
          "ip_addr" => "1.2.3.4",
          "reason"  => "spam source",
        )
      end

      it "logs the subnet notation (via subnetted_ip) when a subnet is banned" do
        create(:ip_ban, ip_addr: "1.2.3.0/24", reason: "subnet spam")
        log = ModAction.last

        expect(log.action).to eq("ip_ban_create")
        expect(log[:values]).to include(
          "ip_addr" => "1.2.3.0/24",
          "reason"  => "subnet spam",
        )
      end
    end

    # -------------------------------------------------------------------------
    # after_destroy → ip_ban_delete
    # -------------------------------------------------------------------------
    describe "after_destroy" do
      it "logs an ip_ban_delete action when an ip ban is destroyed" do
        ban = create(:ip_ban, ip_addr: "5.6.7.8", reason: "was a mistake")
        ban.destroy!
        log = ModAction.last

        expect(log.action).to eq("ip_ban_delete")
        expect(log[:values]).to include(
          "ip_addr" => "5.6.7.8",
          "reason"  => "was a mistake",
        )
      end
    end
  end
end
