# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserIpAddressBackfillJob do
  include_context "as admin"

  let(:user) { create(:user) }

  # NOTE: FactoryBot cascades (posts, the users themselves) carry their own IP
  # columns, so the job legitimately seeds rows for them too. These specs assert
  # on specific controlled IP values rather than on total counts.

  it "aggregates hit_count across a source table's rows" do
    # Post created outside the user's IP scope (as admin, at 127.0.0.1), so only
    # the two comments contribute the 203.0.113.10 evidence.
    post = create(:post)
    CurrentUser.scoped(user, "203.0.113.10") do
      create(:comment, post: post)
      create(:comment, post: post)
    end

    described_class.perform_now
    row = UserIpAddress.find_by(user_id: user.id, ip_addr: "203.0.113.10")
    expect(row).to be_present
    expect(row.hit_count).to eq(2)
    expect(row.subnet.to_s).to eq("203.0.113.0")
  end

  it "counts each dmail once despite the per-mailbox copies" do
    recipient = create(:user)
    CurrentUser.scoped(user, "203.0.113.20") do
      Dmail.create_split(from_id: user.id, to_id: recipient.id, title: "t", body: "b",
                         bypass_limits: true, no_email_notification: true)
    end
    # Sanity: the split really did create both mailbox copies.
    expect(Dmail.where(from_id: user.id).count).to eq(2)

    described_class.perform_now
    row = UserIpAddress.find_by(user_id: user.id, ip_addr: "203.0.113.20")
    expect(row.hit_count).to eq(1)
  end

  it "excludes loopback addresses" do
    create(:user, last_ip_addr: "127.0.0.1", last_logged_in_at: 1.day.ago)
    described_class.perform_now
    expect(UserIpAddress.where(ip_addr: "127.0.0.1")).to be_empty
  end

  it "ignores rows outside the retention window" do
    create(:user, last_ip_addr: "203.0.113.30", last_logged_in_at: 3.years.ago)
    described_class.perform_now
    expect(UserIpAddress.find_by(ip_addr: "203.0.113.30")).to be_nil
  end
end
