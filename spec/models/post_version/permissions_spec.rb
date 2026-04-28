# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostVersion do
  # ------------------------------------------------------------------ #
  # #visible?                                                            #
  # ------------------------------------------------------------------ #

  describe "#visible?" do
    context "as admin" do
      include_context "as admin"

      it "returns true when the associated post is visible" do
        pv = create(:post_version)
        expect(pv).to be_visible
      end

      it "returns false when the associated post is not visible" do
        pv = create(:post_version)
        allow(pv.post).to receive(:visible?).and_return(false)
        expect(pv).not_to be_visible
      end

      it "returns falsy when there is no associated post" do
        pv = create(:post_version)
        allow(pv).to receive(:post).and_return(nil)
        expect(pv).not_to be_visible
      end
    end
  end

  # ------------------------------------------------------------------ #
  # #details_visible?                                                    #
  # ------------------------------------------------------------------ #

  describe "#details_visible?" do
    context "when is_hidden is false" do
      include_context "as member"

      it "returns true for any user" do
        pv = create(:post_version)
        pv.is_hidden = false
        expect(pv.details_visible?).to be true
      end
    end

    context "when is_hidden is true" do
      let(:member)  { create(:user) }
      let(:janitor) { create(:janitor_user) }

      it "returns false for a non-staff user" do
        CurrentUser.user    = member
        CurrentUser.ip_addr = "127.0.0.1"

        pv           = create(:post_version)
        pv.is_hidden = true
        result = pv.details_visible?

        CurrentUser.user    = nil
        CurrentUser.ip_addr = nil
        expect(result).to be false
      end

      it "returns true for a janitor (staff)" do
        CurrentUser.user    = janitor
        CurrentUser.ip_addr = "127.0.0.1"

        pv           = create(:post_version)
        pv.is_hidden = true
        result = pv.details_visible?

        CurrentUser.user    = nil
        CurrentUser.ip_addr = nil
        expect(result).to be true
      end
    end
  end
end
