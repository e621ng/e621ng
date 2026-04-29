# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::User::LoginRemindersController do
  describe "GET /maintenance/user/login_reminder/new" do
    it "returns 200" do
      get new_maintenance_user_login_reminder_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /maintenance/user/login_reminder" do
    context "when the email matches a regular user" do
      let(:user) { create(:user) }

      it "sends a login reminder email" do
        expect { post maintenance_user_login_reminder_path, params: { user: { email: user.email } } }
          .to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it "redirects with the generic notice" do
        post maintenance_user_login_reminder_path, params: { user: { email: user.email } }
        expect(response).to redirect_to(new_maintenance_user_login_reminder_path)
        expect(flash[:notice]).to include("If your email was on file")
      end
    end

    context "when the email matches a moderator" do
      let(:moderator) { create(:moderator_user) }

      it "does not send an email" do
        expect { post maintenance_user_login_reminder_path, params: { user: { email: moderator.email } } }
          .not_to(change { ActionMailer::Base.deliveries.count })
      end

      it "redirects with the same generic notice" do
        post maintenance_user_login_reminder_path, params: { user: { email: moderator.email } }
        expect(response).to redirect_to(new_maintenance_user_login_reminder_path)
        expect(flash[:notice]).to include("If your email was on file")
      end
    end

    context "when the email is unknown" do
      it "does not send an email" do
        expect { post maintenance_user_login_reminder_path, params: { user: { email: "nobody@example.com" } } }
          .not_to(change { ActionMailer::Base.deliveries.count })
      end

      it "redirects with the same generic notice" do
        post maintenance_user_login_reminder_path, params: { user: { email: "nobody@example.com" } }
        expect(response).to redirect_to(new_maintenance_user_login_reminder_path)
        expect(flash[:notice]).to include("If your email was on file")
      end
    end

    context "when the email is blank" do
      it "does not send an email" do
        expect { post maintenance_user_login_reminder_path, params: { user: { email: "" } } }
          .not_to(change { ActionMailer::Base.deliveries.count })
      end

      it "redirects with the same generic notice" do
        post maintenance_user_login_reminder_path, params: { user: { email: "" } }
        expect(response).to redirect_to(new_maintenance_user_login_reminder_path)
        expect(flash[:notice]).to include("If your email was on file")
      end
    end
  end
end
