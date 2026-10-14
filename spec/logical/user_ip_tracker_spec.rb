# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserIpTracker do
  include_context "as member"

  let(:user) { create(:user) }

  # The test env cache is a memory_store (see config/initializers/cache_store.rb),
  # so the hourly debounce is live. Cases that exercise the upsert's conflict
  # path stub Cache.fetch to bypass it.

  describe ".track!" do
    it "inserts a row for a public IP" do
      expect { described_class.track!(user, "203.0.113.7") }
        .to change(UserIpAddress, :count).by(1)
      record = UserIpAddress.last
      expect(record.user_id).to eq(user.id)
      expect(record.ip_addr.to_s).to eq("203.0.113.7")
      expect(record.hit_count).to eq(1)
    end

    it "increments hit_count and keeps one row on a repeat (debounce bypassed)" do
      described_class.track!(user, "203.0.113.7")
      # Clear the debounce key so the second call reaches the upsert's conflict path.
      Cache.delete("user_ip:#{user.id}:203.0.113.7")
      expect { described_class.track!(user, "203.0.113.7") }
        .not_to change(UserIpAddress, :count)
      expect(UserIpAddress.last.hit_count).to eq(2)
    end

    it "debounces a repeat within the window, leaving hit_count untouched" do
      described_class.track!(user, "203.0.113.7")
      expect { described_class.track!(user, "203.0.113.7") }
        .not_to change(UserIpAddress, :count)
      expect(UserIpAddress.last.hit_count).to eq(1)
    end

    it "skips anonymous users" do
      expect { described_class.track!(User.anonymous, "203.0.113.7") }
        .not_to change(UserIpAddress, :count)
    end

    it "skips when the kill switch is off" do
      allow(Danbooru.config.custom_configuration).to receive(:enable_user_ip_tracking?).and_return(false)
      expect { described_class.track!(user, "203.0.113.7") }
        .not_to change(UserIpAddress, :count)
    end

    it "skips private, loopback, and link-local addresses" do
      %w[127.0.0.1 10.0.0.5 192.168.1.1 169.254.1.1 ::1].each do |ip|
        expect { described_class.track!(user, ip) }
          .not_to change(UserIpAddress, :count), "expected #{ip} to be skipped"
      end
    end

    it "normalizes IPv4-mapped IPv6 to the plain v4 address" do
      described_class.track!(user, "::ffff:203.0.113.7")
      expect(UserIpAddress.last.ip_addr.to_s).to eq("203.0.113.7")
    end

    it "swallows errors so tracking can never break the request" do
      allow(UserIpAddress).to receive(:upsert).and_raise(ActiveRecord::StatementInvalid, "boom")
      allow(DanbooruLogger).to receive(:log)
      expect { described_class.track!(user, "203.0.113.7") }.not_to raise_error
      expect(DanbooruLogger).to have_received(:log)
    end
  end
end
