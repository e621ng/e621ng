# frozen_string_literal: true

require "rails_helper"

RSpec.describe Appeal do
  let(:creator) { create(:user) }
  let(:moderator) { create(:moderator_user) }

  before do
    CurrentUser.user    = creator
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  def make_appeal
    create(:appeal).tap { |a| a.update_columns(response: "initial response") }
  end

  # -------------------------------------------------------------------------
  # #log_update
  # -------------------------------------------------------------------------
  describe "#log_update" do
    it "logs an appeal_update ModAction when status changes" do
      appeal = make_appeal
      appeal.update_columns(handler_id: moderator.id)
      expect { appeal.update!(status: "approved", handler: moderator) }
        .to change(ModAction, :count).by(1)
      expect(ModAction.last.action).to eq("appeal_update")
    end

    it "logs an appeal_update ModAction when response changes" do
      appeal = make_appeal
      expect { appeal.update!(response: "New response text.", handler: moderator) }
        .to change(ModAction, :count).by(1)
      expect(ModAction.last.action).to eq("appeal_update")
    end

    it "does not log when neither status nor response changes" do
      appeal = make_appeal
      expect { appeal.update!(reason: "Updated reason text.") }
        .not_to change(ModAction, :count)
    end

    it "stores appeal_id, status, and previous values in the log" do
      appeal = make_appeal
      appeal.update_columns(handler_id: moderator.id)
      appeal.update!(status: "approved", handler: moderator)
      log = ModAction.last
      expect(log[:values]).to include("appeal_id" => appeal.id, "status" => "approved")
    end
  end

  # -------------------------------------------------------------------------
  # #claim! / #unclaim!
  # -------------------------------------------------------------------------
  describe "#claim!" do
    it "sets claimant_id to the given user" do
      appeal = make_appeal
      appeal.claim!(moderator)
      expect(appeal.reload.claimant_id).to eq(moderator.id)
    end

    it "logs an appeal_claim ModAction" do
      appeal = make_appeal
      expect { appeal.claim!(moderator) }.to change(ModAction, :count).by(1)
      expect(ModAction.last.action).to eq("appeal_claim")
      expect(ModAction.last[:values]).to include("appeal_id" => appeal.id)
    end
  end

  describe "#unclaim!" do
    it "clears claimant_id" do
      appeal = make_appeal
      appeal.update_columns(claimant_id: moderator.id)
      appeal.unclaim!(moderator)
      expect(appeal.reload.claimant_id).to be_nil
    end

    it "logs an appeal_unclaim ModAction" do
      appeal = make_appeal
      appeal.update_columns(claimant_id: moderator.id)
      expect { appeal.unclaim!(moderator) }.to change(ModAction, :count).by(1)
      expect(ModAction.last.action).to eq("appeal_unclaim")
      expect(ModAction.last[:values]).to include("appeal_id" => appeal.id)
    end
  end

  # -------------------------------------------------------------------------
  # #create_dmail
  # -------------------------------------------------------------------------
  describe "#create_dmail" do
    it "sends a dmail to the creator when status changes" do
      appeal = make_appeal
      appeal.update_columns(handler_id: moderator.id)
      CurrentUser.user = moderator
      expect { appeal.update!(status: "approved") }.to change(Dmail, :count).by(2)
    end

    it "sends a dmail when send_update_dmail is set and response changes" do
      appeal = make_appeal
      appeal.update_columns(handler_id: moderator.id)
      CurrentUser.user = moderator
      appeal.send_update_dmail = "1"
      expect { appeal.update!(response: "Updated response text.") }.to change(Dmail, :count).by(2)
    end

    it "does not send a dmail when response changes without send_update_dmail" do
      appeal = make_appeal
      appeal.update_columns(handler_id: moderator.id)
      CurrentUser.user = moderator
      expect { appeal.update!(response: "Updated response text.") }.not_to change(Dmail, :count)
    end

    it "does not send a dmail when the creator is the system user" do
      post_flag = create(:post_flag)
      CurrentUser.user = User.system
      appeal = build(:appeal, post_flag: post_flag)
      appeal.creator_id      = User.system.id
      appeal.creator_ip_addr = "127.0.0.1"
      appeal.status          = "pending"
      appeal.accused_id      = post_flag.creator_id
      appeal.save!(validate: false)
      appeal.update_columns(handler_id: moderator.id, response: "initial response")
      CurrentUser.user = moderator
      expect { appeal.update!(status: "approved") }.not_to change(Dmail, :count)
    end
  end
end
