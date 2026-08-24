# frozen_string_literal: true

require "rails_helper"

RSpec.describe UploadKarmaEvent do
  include_context "as admin"

  describe "reason enum" do
    it "pins the stored integers" do
      expect(described_class.reasons).to eq(
        "approved" => 0,
        "unapproved" => 1,
        "deleted" => 2,
        "undeleted" => 3,
        "replacement_penalty" => 4,
        "replacement_penalty_reversed" => 5,
        "replacement_transfer" => 6,
        "owner_change" => 7,
        "staff_override" => 8,
        "queue_bypass" => 9,
      )
    end
  end

  describe "immutability" do
    let(:event) { create(:upload_karma_event) }

    it "allows creation" do
      expect { create(:upload_karma_event) }.to change(described_class, :count).by(1)
    end

    it "refuses updates" do
      expect { event.update!(delta: 5) }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "refuses destroys" do
      expect { event.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end

  describe ".search" do
    let(:user_a) { create(:user) }
    let(:user_b) { create(:user) }
    let!(:event_a) { create(:upload_karma_event, user: user_a, post_id: 1, reason: :approved) }
    let!(:event_b) { create(:upload_karma_event, user: user_b, post_id: 2, reason: :deleted) }

    it "filters by user_id" do
      expect(described_class.search(user_id: user_a.id.to_s)).to contain_exactly(event_a)
    end

    it "filters by user_name" do
      expect(described_class.search(user_name: user_a.name)).to contain_exactly(event_a)
    end

    it "filters by creator_id" do
      expect(described_class.search(creator_id: event_b.creator_id.to_s)).to contain_exactly(event_b)
    end

    it "filters by post_id" do
      expect(described_class.search(post_id: "2")).to contain_exactly(event_b)
    end

    it "filters by reason" do
      expect(described_class.search(reason: "deleted")).to contain_exactly(event_b)
    end

    it "orders by id desc by default" do
      expect(described_class.search({})).to eq([event_b, event_a])
    end
  end
end
