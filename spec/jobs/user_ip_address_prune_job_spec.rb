# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserIpAddressPruneJob do
  include_context "as admin"

  let(:user) { create(:user) }

  it "deletes rows unseen past the retention period and keeps recent ones" do
    stale = create(:user_ip_address, user: user, ip_addr: "203.0.113.1",
                                     last_seen_at: 3.years.ago, first_seen_at: 3.years.ago)
    fresh = create(:user_ip_address, user: user, ip_addr: "203.0.113.2",
                                     last_seen_at: 1.day.ago, first_seen_at: 1.day.ago)

    expect { described_class.perform_now }.to change(UserIpAddress, :count).by(-1)
    expect(UserIpAddress.exists?(fresh.id)).to be(true)
    expect(UserIpAddress.exists?(stale.id)).to be(false)
  end

  it "honors a configured retention period" do
    allow(Danbooru.config.custom_configuration).to receive(:user_ip_retention_period).and_return(30.days)
    old = create(:user_ip_address, user: user, ip_addr: "203.0.113.3",
                                   last_seen_at: 60.days.ago, first_seen_at: 60.days.ago)

    expect { described_class.perform_now }.to change { UserIpAddress.exists?(old.id) }.from(true).to(false)
  end
end
