# frozen_string_literal: true

require "rails_helper"

RSpec.describe HideUserBlipsJob do
  include_context "as admin"

  let(:target_user) { create(:user) }
  let(:other_user)  { create(:user) }

  def perform(user_id = target_user.id)
    described_class.perform_now(user_id, CurrentUser.id)
  end

  describe "#perform" do
    context "when the user has visible blips" do
      let!(:blip_a) { CurrentUser.scoped(target_user) { create(:blip) } }
      let!(:blip_b) { CurrentUser.scoped(target_user) { create(:blip) } }

      it "hides all visible blips by the target user" do
        perform
        expect(blip_a.reload.is_deleted).to be(true)
        expect(blip_b.reload.is_deleted).to be(true)
      end
    end

    context "when the user's only blips are already deleted" do
      before { CurrentUser.scoped(target_user) { create(:deleted_blip) } }

      it "does not increase the deleted blip count" do
        expect { perform }.not_to(change { Blip.where(is_deleted: true).count })
      end
    end

    context "when another user has visible blips" do
      let!(:other_blip) { CurrentUser.scoped(other_user) { create(:blip) } }

      it "does not hide the other user's blips" do
        perform
        expect(other_blip.reload.is_deleted).to be(false)
      end
    end

    context "when the user does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect { perform(0) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
