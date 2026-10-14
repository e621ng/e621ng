# frozen_string_literal: true

require "rails_helper"

RSpec.describe SessionCreator do
  describe "#challenge_user" do
    let(:session) { {} }
    let(:creator) { described_class.new(nil, session, nil, nil, nil) }
    let(:user) { create(:user) }

    def stash_challenge(user_id)
      session[:totp_user_id] = user_id
      session[:totp_expires_at] = 5.minutes.from_now.utc.to_s
      session[:totp_remember] = false
      session[:totp_url] = "/artists"
    end

    it "returns the challenged user while the challenge is live" do
      stash_challenge(user.id)
      expect(creator.challenge_user).to eq(user)
      expect(session[:totp_user_id]).to eq(user.id)
    end

    it "returns nil without touching the session when no challenge exists" do
      expect(creator.challenge_user).to be_nil
      expect(session).to be_empty
    end

    it "clears the challenge when expired" do
      stash_challenge(user.id)
      session[:totp_expires_at] = 1.minute.ago.utc.to_s
      expect(creator.challenge_user).to be_nil
      expect(session).to be_empty
    end

    it "clears the challenge when the timestamp is missing" do
      stash_challenge(user.id)
      session[:totp_expires_at] = nil
      expect(creator.challenge_user).to be_nil
      expect(session.compact).to be_empty
    end

    it "clears the challenge when the challenged user no longer exists" do
      stash_challenge(-1)
      expect(creator.challenge_user).to be_nil
      expect(session).to be_empty
    end
  end
end
