# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          Blip Search & Scopes                               #
# --------------------------------------------------------------------------- #

RSpec.describe Blip do
  include_context "as admin"

  def make_blip(overrides = {})
    create(:blip, **overrides)
  end

  # -------------------------------------------------------------------------
  # Shared fixtures
  # -------------------------------------------------------------------------
  let!(:blip_alpha)   { make_blip(body: "alpha content here") }
  let!(:blip_beta)    { make_blip(body: "beta content here") }
  let!(:blip_deleted) { make_blip(body: "deleted content here", is_deleted: true) }

  # -------------------------------------------------------------------------
  # .search — body_matches param
  # -------------------------------------------------------------------------
  describe "body_matches param" do
    it "returns blips whose body matches the search term" do
      result = Blip.search(body_matches: "alpha")
      expect(result).to include(blip_alpha)
      expect(result).not_to include(blip_beta)
    end

    it "returns all blips when body_matches is absent" do
      result = Blip.search({})
      expect(result).to include(blip_alpha, blip_beta)
    end
  end

  # -------------------------------------------------------------------------
  # .search — response_to param
  # -------------------------------------------------------------------------
  describe "response_to param" do
    it "returns blips that are responses to the given blip id" do
      parent  = make_blip(body: "parent blip content")
      reply   = make_blip(body: "reply blip content", response_to: parent.id)
      unrelated = make_blip(body: "unrelated blip content")

      result = Blip.search(response_to: parent.id.to_s)
      expect(result).to include(reply)
      expect(result).not_to include(unrelated)
    end

    it "returns all blips when response_to is absent" do
      result = Blip.search({})
      expect(result).to include(blip_alpha, blip_beta)
    end
  end

  # -------------------------------------------------------------------------
  # .search — creator_name / creator_id params
  # -------------------------------------------------------------------------
  describe "creator_name param" do
    it "returns only blips created by the named user" do
      other_user = create(:user)
      other_blip = CurrentUser.scoped(other_user, "127.0.0.1") { make_blip(body: "other user blip") }

      result = Blip.search(creator_name: CurrentUser.name)
      expect(result).to include(blip_alpha, blip_beta)
      expect(result).not_to include(other_blip)
    end
  end

  # -------------------------------------------------------------------------
  # .search — ip_addr param
  # -------------------------------------------------------------------------
  describe "ip_addr param" do
    # creator_ip_addr is set from CurrentUser.ip_addr (= "127.0.0.1" in all
    # shared contexts), so all fixtures above have a deterministic IP address.
    it "returns blips whose creator_ip_addr falls within the given CIDR range" do
      result = Blip.search(ip_addr: "127.0.0.1/32")
      expect(result).to include(blip_alpha, blip_beta)
    end

    it "excludes blips whose creator_ip_addr is outside the given CIDR range" do
      result = Blip.search(ip_addr: "10.0.0.0/8")
      expect(result).not_to include(blip_alpha)
    end
  end

  # -------------------------------------------------------------------------
  # .search — order param
  # -------------------------------------------------------------------------
  describe "order param" do
    it "orders by updated_at descending when order is 'updated_at_desc'" do
      result = Blip.search(order: "updated_at_desc").to_a
      expect(result.map(&:updated_at)).to eq(result.map(&:updated_at).sort.reverse)
    end
  end

  # -------------------------------------------------------------------------
  # .accessible scope
  # -------------------------------------------------------------------------
  describe ".accessible" do
    it "returns all blips (including deleted) for a janitor" do
      janitor = create(:janitor_user)
      result = Blip.accessible(janitor)
      expect(result).to include(blip_deleted)
    end

    it "excludes deleted blips for a regular member" do
      member = create(:user)
      result = Blip.accessible(member)
      expect(result).not_to include(blip_deleted)
    end

    it "includes non-deleted blips for a regular member" do
      member = create(:user)
      result = Blip.accessible(member)
      expect(result).to include(blip_alpha, blip_beta)
    end
  end

  # -------------------------------------------------------------------------
  # .for_creator scope
  # -------------------------------------------------------------------------
  describe ".for_creator" do
    it "returns blips created by the given user id" do
      result = Blip.for_creator(blip_alpha.creator_id)
      expect(result).to include(blip_alpha)
    end

    it "returns none when user_id is blank" do
      expect(Blip.for_creator(nil)).to eq(Blip.none)
      expect(Blip.for_creator("")).to eq(Blip.none)
    end
  end
end
