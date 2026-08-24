# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserStatus do
  include_context "as admin"

  let(:user) { create(:user) }

  describe ".adjust_karma" do
    it "applies the delta and records a matching ledger row" do
      described_class.adjust_karma(user.id, 5, :approved, post_id: 123)

      expect(user.user_status.reload.upload_karma).to eq(5)
      event = UploadKarmaEvent.last
      expect(event).to have_attributes(
        user_id: user.id,
        creator_id: CurrentUser.id,
        post_id: 123,
        reason: "approved",
        delta: 5,
        balance: 5,
      )
    end

    it "records extra data" do
      described_class.adjust_karma(user.id, -4, :deleted, post_id: 1, data: { credit_reversed: true })
      expect(UploadKarmaEvent.last.extra_data).to eq({ "credit_reversed" => true })
    end

    it "chains balances across consecutive adjustments" do
      described_class.adjust_karma(user.id, 5, :approved)
      described_class.adjust_karma(user.id, -3, :deleted)

      expect(UploadKarmaEvent.order(:id).pluck(:balance)).to eq([5, 2])
      expect(user.user_status.reload.upload_karma).to eq(2)
    end

    it "does nothing for a zero delta" do
      expect { described_class.adjust_karma(user.id, 0, :approved) }.not_to change(UploadKarmaEvent, :count)
      expect(user.user_status.reload.upload_karma).to eq(0)
    end

    it "silently no-ops for a user without a user_statuses row" do
      user.user_status.delete
      expect { described_class.adjust_karma(user.id, 5, :approved) }.not_to change(UploadKarmaEvent, :count)
    end

    it "rolls back the balance change when the ledger insert fails" do
      allow(UploadKarmaEvent).to receive(:create!).and_raise("ledger insert failed")

      expect { described_class.adjust_karma(user.id, 5, :approved) }.to raise_error("ledger insert failed")
      expect(user.user_status.reload.upload_karma).to eq(0)
    end
  end
end
