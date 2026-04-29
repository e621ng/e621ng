# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::User::PasswordsController do
  before { CurrentUser.ip_addr = "127.0.0.1" }

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  let(:user) { create(:user) }

  describe "GET /users/:user_id/password/edit" do
    context "as anonymous" do
      # The controller has no logged_in_only guard, so anonymous requests are not redirected.
      it "returns 200" do
        get edit_user_password_path(user)
        expect(response).to have_http_status(:ok)
      end
    end

    context "as a member" do
      before { sign_in_as user }

      it "returns 200" do
        get edit_user_password_path(user)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
