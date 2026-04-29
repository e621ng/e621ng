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
end
