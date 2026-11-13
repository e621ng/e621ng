# frozen_string_literal: true

require "rails_helper"

# E6SEC-506: API credentials on a browser request must never change the cookie login.
RSpec.describe "API credentials vs. cookie login" do
  include_context "as member"

  let(:victim) { create(:user) }
  let(:attacker) { create(:user) }
  let(:attacker_key) { create(:api_key, user: attacker) }

  before do
    allow(RateLimiter).to receive(:new).and_return(instance_double(RateLimiter, throttled?: false, hit!: 1, reset!: nil))
    post session_path, params: { session: { name: victim.name, password: "hexerade", remember: "1" } }
  end

  def login_state
    [session[:user_id], cookies["remember"]]
  end

  it "starts from a remembered victim login" do
    expect(login_state).to match([victim.id, be_present])
  end

  it "keeps the victim logged in when bogus login/api_key params fail" do
    before_state = login_state
    get posts_path, params: { login: "x", api_key: "y" }
    expect(response).to have_http_status(:unauthorized)
    expect(login_state).to eq(before_state)
  end

  it "keeps the victim logged in when a bogus Basic header fails" do
    before_state = login_state
    get posts_path, headers: { "Authorization" => "Basic #{Base64.strict_encode64('x:y')}" }
    expect(response).to have_http_status(:unauthorized)
    expect(login_state).to eq(before_state)
  end

  it "does not hand the remember cookie to valid attacker credentials" do
    before_state = login_state
    get posts_path, params: { login: attacker.name, api_key: attacker_key.key }
    expect(response).to have_http_status(:ok)
    expect(login_state).to eq(before_state)

    # Browser restart: the session cookie is gone, the remember cookie restores the login.
    cookies.delete("_danbooru_session")
    get posts_path
    expect(session[:user_id]).to eq(victim.id)
  end

  it "keeps the victim logged in when a banned account's key is used" do
    banned_key = create(:api_key, user: create(:banned_user))
    before_state = login_state
    get posts_path, params: { login: banned_key.user.name, api_key: banned_key.key }
    expect(response).to have_http_status(:unauthorized)
    expect(login_state).to eq(before_state)
  end

  it "still clears the cookie login when the session user no longer exists" do
    victim.delete
    get posts_path
    expect(response).to have_http_status(:unauthorized)
    expect(session[:user_id]).to be_nil
    expect(cookies["remember"]).to be_blank
  end
end
