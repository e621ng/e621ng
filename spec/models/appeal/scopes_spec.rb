# frozen_string_literal: true

require "rails_helper"

RSpec.describe Appeal do
  include_context "as member"

  # -------------------------------------------------------------------------
  # .for_creator
  # -------------------------------------------------------------------------
  describe ".for_creator" do
    let(:creator) { CurrentUser.user }
    let!(:own_appeal)   { create(:appeal) }
    let!(:other_appeal) do
      old = CurrentUser.user
      CurrentUser.user = create(:user)
      a = create(:appeal)
      CurrentUser.user = old
      a
    end

    it "includes appeals by the given creator" do
      expect(Appeal.for_creator(creator.id)).to include(own_appeal)
    end

    it "excludes appeals by other creators" do
      expect(Appeal.for_creator(creator.id)).not_to include(other_appeal)
    end
  end

  # -------------------------------------------------------------------------
  # .for_accused
  # -------------------------------------------------------------------------
  describe ".for_accused" do
    let(:accused_a) { create(:user) }
    let(:accused_b) { create(:user) }
    let!(:appeal_a) { create(:appeal).tap { |a| a.update_columns(accused_id: accused_a.id) } }
    let!(:appeal_b) { create(:appeal).tap { |a| a.update_columns(accused_id: accused_b.id) } }

    it "includes appeals against the given accused user" do
      expect(Appeal.for_accused(accused_a.id)).to include(appeal_a)
    end

    it "excludes appeals against other users" do
      expect(Appeal.for_accused(accused_a.id)).not_to include(appeal_b)
    end
  end

  # -------------------------------------------------------------------------
  # .active
  # -------------------------------------------------------------------------
  describe ".active" do
    let!(:pending_appeal)  { create(:appeal) }
    let!(:partial_appeal)  { create(:appeal).tap { |a| a.update_columns(status: "partial") } }
    let!(:approved_appeal) { create(:appeal).tap { |a| a.update_columns(status: "approved") } }

    it "includes pending appeals" do
      expect(Appeal.active).to include(pending_appeal)
    end

    it "includes partial appeals" do
      expect(Appeal.active).to include(partial_appeal)
    end

    it "excludes approved appeals" do
      expect(Appeal.active).not_to include(approved_appeal)
    end
  end

  # -------------------------------------------------------------------------
  # .visible
  # -------------------------------------------------------------------------
  describe ".visible" do
    let(:creator) { CurrentUser.user }
    let(:janitor) { create(:janitor_user) }
    let!(:own_appeal) { create(:appeal) }
    let!(:other_appeal) do
      old = CurrentUser.user
      CurrentUser.user = create(:user)
      a = create(:appeal)
      CurrentUser.user = old
      a
    end

    context "for a janitor" do
      it "returns all appeals" do
        result = Appeal.visible(janitor)
        expect(result).to include(own_appeal, other_appeal)
      end
    end

    context "for a regular member" do
      it "returns only their own appeals" do
        result = Appeal.visible(creator)
        expect(result).to include(own_appeal)
        expect(result).not_to include(other_appeal)
      end
    end
  end
end
