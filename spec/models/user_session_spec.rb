# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserSession do
  let(:user) { create(:user) }
  let(:request) { instance_double(ActionDispatch::Request, remote_ip: "203.0.113.9", user_agent: "Mozilla/5.0 (X11; Linux x86_64) Firefox/132.0") }
  # Untouched rows have last_seen_at == created_at exactly; evaluate the time once.
  let(:yesterday) { 1.day.ago }
  let(:two_hours_ago) { 2.hours.ago }
  let(:five_minutes_ago) { 5.minutes.ago }

  describe ".mint!" do
    it "creates an active row and returns the secret, storing only its digest" do
      record, secret = described_class.mint!(user, request: request, remember: false)
      expect(record).to be_active
      expect(record.secret_digest).to eq(Digest::SHA256.hexdigest(secret))
      expect(record.secret_digest).not_to include(secret)
      expect(record.site).to eq(CurrentSite.id)
      expect(record.created_ip.to_s).to eq("203.0.113.9")
      expect(record.last_ip.to_s).to eq("203.0.113.9")
      expect(record.user_agent).to include("Firefox")
      expect(record.expires_at).to be_within(5.seconds).of(Time.now + described_class::IDLE_TIMEOUT)
    end

    it "uses the longer timeout for remembered logins" do
      record, = described_class.mint!(user, request: request, remember: true)
      expect(record.remember).to be true
      expect(record.expires_at).to be_within(5.seconds).of(Time.now + described_class::REMEMBER_TIMEOUT)
    end

    it "starts untouched and is pruned once the grace period passes without activity" do
      record, = travel_to(2.hours.ago) { described_class.mint!(user, request: request, remember: false) }
      expect(record.reload).not_to be_touched
      expect(record.created_at).to eq(record.last_seen_at)
      expect(user.user_sessions.listed).not_to include(record)

      described_class.prune!
      expect(described_class.exists?(record.id)).to be false
    end

    it "is kept by the prune while the grace period is running" do
      record, = described_class.mint!(user, request: request, remember: false)
      expect(record).not_to be_touched
      described_class.prune!
      expect(described_class.exists?(record.id)).to be true
    end

    it "truncates and scrubs the user agent" do
      bad = instance_double(ActionDispatch::Request, remote_ip: "203.0.113.9", user_agent: "#{'a' * 2000}\xFF".b)
      record, = described_class.mint!(user, request: bad, remember: false)
      expect(record.user_agent.length).to be <= described_class::USER_AGENT_LIMIT
      expect(record.user_agent).to be_valid_encoding
    end

    it "revokes the least recently used touched rows beyond the cap, leaving untouched rows alone" do
      stub_const("UserSession::MAX_ACTIVE", 2)
      oldest = create(:user_session, user: user, created_at: 3.days.ago, last_seen_at: 2.days.ago)
      newer = create(:user_session, user: user, created_at: 2.days.ago, last_seen_at: 1.hour.ago)
      untouched = create(:user_session, user: user, created_at: yesterday, last_seen_at: yesterday)
      create(:user_session, user: user, created_at: 2.days.ago, last_seen_at: 1.minute.ago)

      described_class.mint!(user, request: request, remember: false)

      expect(oldest.reload.revoked_reason).to eq("cap")
      expect(newer.reload).to be_active
      expect(untouched.reload).to be_active
    end
  end

  describe ".authenticate" do
    let!(:record) { create(:user_session, user: user, secret: "s3cret") }

    it "returns the row for the right secret" do
      expect(described_class.authenticate(record.id, "s3cret")).to eq(record)
    end

    it "returns nil for a wrong, missing or non-string secret, or an unknown id" do
      expect(described_class.authenticate(record.id, "nope")).to be_nil
      expect(described_class.authenticate(record.id, nil)).to be_nil
      expect(described_class.authenticate(record.id, "")).to be_nil
      expect(described_class.authenticate(record.id, 123)).to be_nil
      expect(described_class.authenticate(nil, "s3cret")).to be_nil
      expect(described_class.authenticate(record.id + 1000, "s3cret")).to be_nil
    end

    it "does not check whether the row is still active" do
      record.revoke!("user")
      expect(described_class.authenticate(record.id, "s3cret")).to eq(record)
    end
  end

  describe "#active?" do
    it "is false once revoked or expired" do
      expect(create(:user_session, user: user)).to be_active
      expect(create(:revoked_user_session, user: user)).not_to be_active
      expect(create(:user_session, user: user, expires_at: 1.minute.ago)).not_to be_active
    end
  end

  describe ".revoke_all!" do
    it "revokes every active row except the given one and returns the count" do
      keep = create(:user_session, user: user)
      other = create(:user_session, user: user)
      already = create(:revoked_user_session, user: user)
      foreign = create(:user_session)

      expect(described_class.revoke_all!(user, reason: "others", except: keep)).to eq(1)
      expect(keep.reload).to be_active
      expect(other.reload.revoked_reason).to eq("others")
      expect(already.reload.revoked_reason).to eq("user")
      expect(foreign.reload).to be_active
    end
  end

  describe ".legacy_blocked?" do
    it "is true when any adopted row with the key is revoked or expired" do
      expect(described_class.legacy_blocked?(user, "k")).to be false
      create(:user_session, user: user, legacy_key: "k")
      expect(described_class.legacy_blocked?(user, "k")).to be false
      create(:user_session, user: user, legacy_key: "k", expires_at: 1.minute.ago)
      expect(described_class.legacy_blocked?(user, "k")).to be true
    end

    it "ignores other users' rows" do
      create(:revoked_user_session, legacy_key: "k")
      expect(described_class.legacy_blocked?(user, "k")).to be false
    end
  end

  describe ".prune!" do
    it "deletes rows past retention and untouched rows past the grace period" do
      old_revoked = create(:revoked_user_session, user: user, revoked_at: 31.days.ago)
      recent_revoked = create(:revoked_user_session, user: user, revoked_at: 2.days.ago)
      old_expired = create(:user_session, user: user, expires_at: 31.days.ago)
      untouched = create(:user_session, user: user, created_at: two_hours_ago, last_seen_at: two_hours_ago)
      fresh_untouched = create(:user_session, user: user, created_at: five_minutes_ago, last_seen_at: five_minutes_ago)
      live = create(:user_session, user: user, created_at: 2.days.ago, last_seen_at: 1.minute.ago)

      described_class.prune!

      expect(described_class.where(id: [old_revoked.id, old_expired.id, untouched.id])).to be_empty
      expect(described_class.where(id: [recent_revoked.id, fresh_untouched.id, live.id]).count).to eq(3)
    end
  end

  describe ".listed" do
    it "hides untouched rows older than the grace period and dead rows" do
      shown = create(:user_session, user: user, created_at: 2.days.ago, last_seen_at: 1.minute.ago)
      fresh = create(:user_session, user: user, created_at: five_minutes_ago, last_seen_at: five_minutes_ago)
      create(:user_session, user: user, created_at: two_hours_ago, last_seen_at: two_hours_ago)
      create(:revoked_user_session, user: user, created_at: 2.days.ago, last_seen_at: 1.minute.ago)

      expect(user.user_sessions.listed).to contain_exactly(shown, fresh)
    end
  end

  it "hides the digest and legacy key from JSON" do
    record = create(:user_session, user: user, legacy_key: "k")
    expect(record.as_json.keys).not_to include("secret_digest", "legacy_key")
  end
end
