# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdminRouteConstraint do
  subject(:constraint) { described_class.new }

  let(:env)     { Rack::MockRequest.env_for("/sidekiq", "REMOTE_ADDR" => "1.2.3.200").merge("rack.session" => ActionController::TestSession.new) }
  let(:request) { ActionDispatch::Request.new(env) }
  let(:admin)   { create(:admin_user) }

  def sign_in(user, authenticated_at: Time.now.utc)
    request.session[:user_id] = user.id
    request.session[:ph] = user.password_token
    request.session[:last_authenticated_at] = authenticated_at.to_s
  end

  it "matches a freshly authenticated admin" do
    sign_in(admin)
    expect(constraint.matches?(request)).to be true
  end

  it "rejects a request without a session" do
    expect(constraint.matches?(request)).to be false
  end

  it "rejects a non-admin" do
    sign_in(create(:moderator_user))
    expect(constraint.matches?(request)).to be false
  end

  it "rejects a deleted user id without raising" do
    request.session[:user_id] = 999_999
    expect(constraint.matches?(request)).to be false
  end

  it "rejects a session invalidated by a password change" do
    sign_in(admin)
    admin.update_columns(bcrypt_password_hash: User.bcrypt("a-different-password"))
    expect(constraint.matches?(request)).to be false
  end

  it "rejects a banned IP" do
    sign_in(admin)
    create(:ip_ban, ip_addr: "1.2.3.200")
    expect(constraint.matches?(request)).to be false
  end

  it "rejects a bearer token without a cookie session" do
    env["HTTP_AUTHORIZATION"] = "Bearer anything"
    expect(constraint.matches?(request)).to be false
  end

  context "when the login is older than the reauth window" do
    before { sign_in(admin, authenticated_at: 2.hours.ago.utc) }

    it "rejects by default" do
      expect(constraint.matches?(request)).to be false
    end

    it "matches with require_reauth: false" do
      expect(described_class.new(require_reauth: false).matches?(request)).to be true
    end
  end

  it "rejects a missing last_authenticated_at" do
    sign_in(admin)
    request.session.delete(:last_authenticated_at)
    expect(constraint.matches?(request)).to be false
  end
end
