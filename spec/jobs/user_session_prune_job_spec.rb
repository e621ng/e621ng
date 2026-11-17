# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserSessionPruneJob do
  let(:user) { create(:user) }

  it "deletes rows past retention and keeps live ones" do
    stale = create(:revoked_user_session, user: user, revoked_at: 40.days.ago)
    live = create(:user_session, user: user, created_at: 1.day.ago, last_seen_at: 1.minute.ago)

    expect { described_class.new.perform }.to change(UserSession, :count).by(-1)
    expect(UserSession.exists?(stale.id)).to be(false)
    expect(UserSession.exists?(live.id)).to be(true)
  end
end
