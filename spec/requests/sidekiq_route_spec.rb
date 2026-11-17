# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sidekiq dashboard access" do
  let(:user) { create(:user) }

  before do
    allow(RateLimiter).to receive(:new).and_return(instance_double(RateLimiter, throttled?: false, hit!: 1, reset!: nil))
  end

  # Promoting after login keeps password_token unchanged and skips the staff TOTP requirement.
  def sign_in_admin
    make_session(user)
    user.update_columns(level: UserLevel::ADMIN)
  end

  it "returns 404 for anonymous users" do
    get "/sidekiq"
    expect(response).to have_http_status(:not_found)
  end

  it "serves the dashboard to a freshly authenticated admin" do
    sign_in_admin
    get "/sidekiq"
    expect(response).to have_http_status(:ok)
  end

  it "returns 404 once the password has changed" do
    sign_in_admin
    user.update_columns(bcrypt_password_hash: User.bcrypt("a-different-password"))
    get "/sidekiq"
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 once the session row has been revoked elsewhere" do
    sign_in_admin
    UserSession.find(session[:sid]).revoke!("user")
    get "/sidekiq"
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 from a banned IP" do
    sign_in_admin
    create(:ip_ban, ip_addr: "1.2.3.200")
    get "/sidekiq", env: { "REMOTE_ADDR" => "1.2.3.200" }
    expect(response).to have_http_status(:not_found)
  end

  it "sends an admin with an old login to confirm their password" do
    sign_in_admin
    travel(2.hours) do
      get "/sidekiq/queues"
      expect(response).to redirect_to(confirm_password_session_path(url: "/sidekiq/queues"))
    end
  end
end
