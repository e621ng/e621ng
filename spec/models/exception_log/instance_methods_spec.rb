# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                      ExceptionLog Instance Methods                           #
# --------------------------------------------------------------------------- #

RSpec.describe ExceptionLog do
  include_context "as admin"

  def make_log(overrides = {})
    create(:exception_log, **overrides)
  end

  # ---------------------------------------------------------------------------
  # #user
  # ---------------------------------------------------------------------------

  describe "#user" do
    context "when user_id column is set (modern record)" do
      it "returns the associated user" do
        user = create(:user)
        log  = make_log(user_id: user.id)
        expect(log.user).to eq(user)
      end
    end

    context "when user_id is nil and extra_params has no user_id (anonymous)" do
      it "returns nil" do
        log = make_log(user_id: nil, extra_params: {})
        expect(log.user).to be_nil
      end
    end

    context "when user_id column is nil but extra_params contains a user_id (legacy record)" do
      it "falls back to looking up the user from extra_params" do
        user = create(:user)
        log  = make_log(user_id: user.id, extra_params: { "user_id" => user.id })
        # Simulate a legacy record: clear the user_id column without touching extra_params
        log.update_columns(user_id: nil)

        expect(log.user).to eq(user)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #viewable_message and #viewable_extra_params
  # ---------------------------------------------------------------------------

  describe "#viewable_message" do
    it "returns the full message for admins" do
      log = make_log(message: "Error from 1.2.3.4 and admin@example.com")
      expect(log.viewable_message).to eq("Error from 1.2.3.4 and admin@example.com")
    end

    context "when not admin" do
      include_context "as member"

      it "scrubs IPs and emails from the message" do
        log = make_log(message: "Error from 1.2.3.4 and admin@example.com")
        expect(log.viewable_message).to eq("Error from [IP PROTECTED] and [EMAIL PROTECTED]")
      end
    end
  end

  describe "#viewable_extra_params" do
    let(:raw_extra) do
      {
        "user_agent" => "MyAwesomeBot/1.2.3.4 (by User1234)",
        "note" => "Contact user@example.com 1.2.3.4",
        "nested" => { "inner" => "admin@example.com 4.3.2.1" },
      }
    end

    it "returns raw extra params for admins" do
      log = make_log(extra_params: raw_extra)
      expect(log.viewable_extra_params).to eq(raw_extra)
    end

    context "when not admin" do
      include_context "as member"

      it "preserves the user agent but scrubs emails and IPs in other fields" do
        log = make_log(extra_params: raw_extra)
        ve = log.viewable_extra_params

        expect(ve["user_agent"]).to eq("MyAwesomeBot/1.2.3.4 (by User1234)")
        expect(ve["note"]).to eq("Contact [EMAIL PROTECTED] [IP PROTECTED]")
        expect(ve["nested"]["inner"]).to eq("[EMAIL PROTECTED] [IP PROTECTED]")
      end
    end
  end
end
