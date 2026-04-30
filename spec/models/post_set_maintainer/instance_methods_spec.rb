# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                  PostSetMaintainer Instance Methods                         #
# --------------------------------------------------------------------------- #
# Dmail.count is used to verify notifications without asserting on exact text.
# Each create(:post_set_maintainer) triggers notify_maintainer (+1 Dmail).
# Per-example assertions use `change(Dmail, :count).by(N)` to stay isolated.

RSpec.describe PostSetMaintainer do
  include_context "as member"

  let(:owner)   { CurrentUser.user }
  let(:invitee) { create(:user) }
  let(:set)     { create(:public_post_set, creator: owner) }

  # -------------------------------------------------------------------------
  # #notify_maintainer (triggered via after_create)
  # -------------------------------------------------------------------------
  describe "#notify_maintainer" do
    it "sends a Dmail to the invited user when the record is created" do
      expect { create(:post_set_maintainer, post_set: set, user: invitee) }
        .to change(Dmail, :count).by(1)
    end
  end

  # -------------------------------------------------------------------------
  # #cancel!
  # -------------------------------------------------------------------------
  describe "#cancel!" do
    context "when status is pending" do
      let!(:maintainer) { create(:post_set_maintainer, post_set: set, user: invitee) }

      it "transitions status to cooldown" do
        expect { maintainer.cancel! }
          .to change { maintainer.reload.status }.from("pending").to("cooldown")
      end

      it "does not destroy the record" do
        maintainer.cancel!
        expect(PostSetMaintainer.exists?(maintainer.id)).to be true
      end

      it "does not send a Dmail" do
        expect { maintainer.cancel! }.not_to change(Dmail, :count)
      end
    end

    context "when status is approved" do
      let!(:maintainer) { create(:approved_post_set_maintainer, post_set: set, user: invitee) }

      it "destroys the record" do
        maintainer.cancel!
        expect(PostSetMaintainer.exists?(maintainer.id)).to be false
      end

      it "sends a Dmail to the invitee" do
        expect { maintainer.cancel! }.to change(Dmail, :count).by(1)
      end
    end
  end

  # -------------------------------------------------------------------------
  # #approve!
  # -------------------------------------------------------------------------
  describe "#approve!" do
    let!(:maintainer) { create(:post_set_maintainer, post_set: set, user: invitee) }

    it "changes status to approved" do
      expect { maintainer.approve! }
        .to change { maintainer.reload.status }.from("pending").to("approved")
    end

    it "sends a Dmail to the set creator" do
      expect { maintainer.approve! }.to change(Dmail, :count).by(1)
    end
  end

  # -------------------------------------------------------------------------
  # #deny!
  # -------------------------------------------------------------------------
  describe "#deny!" do
    context "when status is pending" do
      let!(:maintainer) { create(:post_set_maintainer, post_set: set, user: invitee) }

      it "destroys the record" do
        maintainer.deny!
        expect(PostSetMaintainer.exists?(maintainer.id)).to be false
      end

      it "sends a Dmail to the set creator" do
        expect { maintainer.deny! }.to change(Dmail, :count).by(1)
      end
    end

    context "when status is approved" do
      let!(:maintainer) { create(:approved_post_set_maintainer, post_set: set, user: invitee) }

      it "destroys the record" do
        maintainer.deny!
        expect(PostSetMaintainer.exists?(maintainer.id)).to be false
      end

      it "sends a Dmail to the set creator" do
        expect { maintainer.deny! }.to change(Dmail, :count).by(1)
      end
    end
  end

  # -------------------------------------------------------------------------
  # #block!
  # -------------------------------------------------------------------------
  describe "#block!" do
    context "when status is pending" do
      let!(:maintainer) { create(:post_set_maintainer, post_set: set, user: invitee) }

      it "changes status to blocked" do
        expect { maintainer.block! }
          .to change { maintainer.reload.status }.from("pending").to("blocked")
      end

      it "does not destroy the record" do
        maintainer.block!
        expect(PostSetMaintainer.exists?(maintainer.id)).to be true
      end

      it "sends a Dmail to the set creator" do
        expect { maintainer.block! }.to change(Dmail, :count).by(1)
      end
    end

    context "when status is approved" do
      let!(:maintainer) { create(:approved_post_set_maintainer, post_set: set, user: invitee) }

      it "changes status to blocked" do
        expect { maintainer.block! }
          .to change { maintainer.reload.status }.from("approved").to("blocked")
      end

      it "does not destroy the record" do
        maintainer.block!
        expect(PostSetMaintainer.exists?(maintainer.id)).to be true
      end

      it "sends a Dmail to the set creator" do
        expect { maintainer.block! }.to change(Dmail, :count).by(1)
      end
    end
  end
end
