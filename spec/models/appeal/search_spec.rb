# frozen_string_literal: true

require "rails_helper"

RSpec.describe Appeal do
  include_context "as member"

  # -------------------------------------------------------------------------
  # creator param
  # -------------------------------------------------------------------------
  describe ".search creator_name param" do
    let(:creator) { CurrentUser.user }
    let!(:own_appeal) { create(:appeal) }
    let!(:other_appeal) do
      old = CurrentUser.user
      CurrentUser.user = create(:user)
      a = create(:appeal)
      CurrentUser.user = old
      a
    end

    it "filters by creator name" do
      result = Appeal.search(creator_name: creator.name)
      expect(result).to include(own_appeal)
      expect(result).not_to include(other_appeal)
    end
  end

  # -------------------------------------------------------------------------
  # claimant param
  # -------------------------------------------------------------------------
  describe ".search claimant_name param" do
    let(:claimant)   { create(:janitor_user) }
    let!(:claimed)   { create(:appeal).tap { |a| a.update_columns(claimant_id: claimant.id) } }
    let!(:unclaimed) { create(:appeal) }

    it "filters by claimant name" do
      result = Appeal.search(claimant_name: claimant.name)
      expect(result).to include(claimed)
      expect(result).not_to include(unclaimed)
    end
  end

  # -------------------------------------------------------------------------
  # accused param
  # -------------------------------------------------------------------------
  describe ".search accused_name param" do
    let(:accused_a) { create(:user) }
    let(:accused_b) { create(:user) }
    let!(:appeal_a) { create(:appeal).tap { |a| a.update_columns(accused_id: accused_a.id) } }
    let!(:appeal_b) { create(:appeal).tap { |a| a.update_columns(accused_id: accused_b.id) } }

    it "filters by accused name" do
      result = Appeal.search(accused_name: accused_a.name)
      expect(result).to include(appeal_a)
      expect(result).not_to include(appeal_b)
    end
  end

  # -------------------------------------------------------------------------
  # disp_id param
  # -------------------------------------------------------------------------
  describe ".search disp_id param" do
    let!(:appeal_a) { create(:appeal) }
    let!(:appeal_b) { create(:appeal) }

    it "filters by disp_id" do
      result = Appeal.search(disp_id: appeal_a.disp_id.to_s)
      expect(result).to include(appeal_a)
      expect(result).not_to include(appeal_b)
    end
  end

  # -------------------------------------------------------------------------
  # qtype param
  # -------------------------------------------------------------------------
  describe ".search qtype param" do
    let!(:flag_appeal) { create(:appeal) }

    it "filters by qtype" do
      expect(Appeal.search(qtype: "flag")).to include(flag_appeal)
    end
  end

  # -------------------------------------------------------------------------
  # reason param
  # -------------------------------------------------------------------------
  describe ".search reason param" do
    let!(:matching)     { create(:appeal, reason: "Please remove this flag") }
    let!(:non_matching) { create(:appeal, reason: "Unrelated reason text") }

    it "returns appeals whose reason matches the search string" do
      expect(Appeal.search(reason: "remove this flag")).to include(matching)
    end

    it "excludes appeals whose reason does not match" do
      expect(Appeal.search(reason: "remove this flag")).not_to include(non_matching)
    end
  end

  # -------------------------------------------------------------------------
  # status param
  # -------------------------------------------------------------------------
  describe ".search status param" do
    let!(:pending_appeal)  { create(:appeal) }
    let!(:partial_appeal)  { create(:appeal).tap { |a| a.update_columns(status: "partial") } }
    let!(:approved_appeal) { create(:appeal).tap { |a| a.update_columns(status: "approved") } }

    it "filters pending appeals" do
      result = Appeal.search(status: "pending")
      expect(result).to include(pending_appeal)
      expect(result).not_to include(partial_appeal, approved_appeal)
    end

    it "filters partial appeals" do
      result = Appeal.search(status: "partial")
      expect(result).to include(partial_appeal)
      expect(result).not_to include(pending_appeal, approved_appeal)
    end

    it "filters approved appeals" do
      result = Appeal.search(status: "approved")
      expect(result).to include(approved_appeal)
      expect(result).not_to include(pending_appeal, partial_appeal)
    end
  end

  # -------------------------------------------------------------------------
  # status: pending_claimed / pending_unclaimed
  # -------------------------------------------------------------------------
  describe ".search status pending_claimed / pending_unclaimed" do
    let(:claimant)    { create(:janitor_user) }
    let!(:unclaimed)  { create(:appeal) }
    let!(:claimed) do
      create(:appeal).tap { |a| a.update_columns(claimant_id: claimant.id) }
    end

    it "pending_claimed returns only pending appeals with a claimant" do
      result = Appeal.search(status: "pending_claimed")
      expect(result).to include(claimed)
      expect(result).not_to include(unclaimed)
    end

    it "pending_unclaimed returns only pending appeals without a claimant" do
      result = Appeal.search(status: "pending_unclaimed")
      expect(result).to include(unclaimed)
      expect(result).not_to include(claimed)
    end
  end

  # -------------------------------------------------------------------------
  # default ordering
  # -------------------------------------------------------------------------
  describe ".search default order" do
    let!(:approved) { create(:appeal).tap { |a| a.update_columns(status: "approved") } }
    let!(:partial)  { create(:appeal).tap { |a| a.update_columns(status: "partial") } }
    let!(:pending)  { create(:appeal) }

    it "orders pending before partial before approved" do
      ids = Appeal.search({}).ids
      expect(ids.index(pending.id)).to be < ids.index(partial.id)
      expect(ids.index(partial.id)).to be < ids.index(approved.id)
    end

    it "orders newer pending appeals before older pending appeals" do
      older = create(:appeal)
      older.update_columns(created_at: 1.hour.ago)
      newer = create(:appeal)

      ids = Appeal.search({}).ids
      expect(ids.index(newer.id)).to be < ids.index(older.id)
    end
  end
end
