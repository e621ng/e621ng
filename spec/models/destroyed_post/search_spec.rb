# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         DestroyedPost.search                                #
# --------------------------------------------------------------------------- #

RSpec.describe DestroyedPost do
  let(:admin) { create(:admin_user) }

  before { CurrentUser.user = admin }
  after  { CurrentUser.user = nil }

  def make_dp(overrides = {})
    create(:destroyed_post, **overrides)
  end

  describe ".search" do
    # -------------------------------------------------------------------------
    # destroyer filters
    # -------------------------------------------------------------------------
    describe "destroyer filter" do
      let(:other_destroyer) { create(:user) }
      let!(:dp)       { make_dp }
      let!(:other_dp) { make_dp(destroyer: other_destroyer) }

      it "filters by destroyer_name" do
        results = DestroyedPost.search(destroyer_name: dp.destroyer.name)
        expect(results).to include(dp)
        expect(results).not_to include(other_dp)
      end

      it "filters by destroyer_id" do
        results = DestroyedPost.search(destroyer_id: dp.destroyer_id)
        expect(results).to include(dp)
        expect(results).not_to include(other_dp)
      end
    end

    # -------------------------------------------------------------------------
    # uploader filters
    # -------------------------------------------------------------------------
    describe "uploader filter" do
      let(:other_uploader) { create(:user) }
      let!(:dp)       { create(:destroyed_post_with_uploader) }
      let!(:other_dp) { create(:destroyed_post_with_uploader, uploader: other_uploader) }

      it "filters by uploader_name" do
        results = DestroyedPost.search(uploader_name: dp.uploader.name)
        expect(results).to include(dp)
        expect(results).not_to include(other_dp)
      end

      it "filters by uploader_id" do
        results = DestroyedPost.search(uploader_id: dp.uploader_id)
        expect(results).to include(dp)
        expect(results).not_to include(other_dp)
      end
    end

    # -------------------------------------------------------------------------
    # destroyer_ip_addr
    # -------------------------------------------------------------------------
    describe "destroyer_ip_addr filter" do
      let!(:dp)       { make_dp(destroyer_ip_addr: "10.0.0.1") }
      let!(:other_dp) { make_dp(destroyer_ip_addr: "192.168.1.1") }

      it "returns records whose destroyer_ip_addr falls within the CIDR range" do
        results = DestroyedPost.search(destroyer_ip_addr: "10.0.0.0/8")
        expect(results).to include(dp)
        expect(results).not_to include(other_dp)
      end

      it "returns a single record when given an exact IP" do
        results = DestroyedPost.search(destroyer_ip_addr: "10.0.0.1")
        expect(results).to include(dp)
        expect(results).not_to include(other_dp)
      end
    end

    # -------------------------------------------------------------------------
    # uploader_ip_addr
    # -------------------------------------------------------------------------
    describe "uploader_ip_addr filter" do
      let!(:dp)       { create(:destroyed_post_with_uploader, uploader_ip_addr: "10.0.0.2") }
      let!(:other_dp) { create(:destroyed_post_with_uploader, uploader_ip_addr: "192.168.1.2") }

      it "returns records whose uploader_ip_addr falls within the CIDR range" do
        results = DestroyedPost.search(uploader_ip_addr: "10.0.0.0/8")
        expect(results).to include(dp)
        expect(results).not_to include(other_dp)
      end
    end

    # -------------------------------------------------------------------------
    # post_id
    # -------------------------------------------------------------------------
    describe "post_id filter" do
      let!(:dp)       { make_dp }
      let!(:other_dp) { make_dp }

      it "includes the matching record" do
        results = DestroyedPost.search(post_id: dp.post_id.to_s)
        expect(results).to include(dp)
        expect(results).not_to include(other_dp)
      end
    end

    # -------------------------------------------------------------------------
    # md5
    # -------------------------------------------------------------------------
    describe "md5 filter" do
      let!(:dp)       { make_dp(md5: "abc123def456abc123def456abc12345") }
      let!(:other_dp) { make_dp(md5: "999000aaa111bbb222ccc333ddd44455") }

      it "includes the matching record" do
        results = DestroyedPost.search(md5: dp.md5)
        expect(results).to include(dp)
        expect(results).not_to include(other_dp)
      end
    end

    # -------------------------------------------------------------------------
    # ordering
    # -------------------------------------------------------------------------
    describe "order" do
      it "returns records newest-first by default" do
        first  = make_dp
        second = make_dp
        results = DestroyedPost.search({}).to_a
        expect(results.index(second)).to be < results.index(first)
      end

      it "returns records oldest-first with order: id_asc" do
        first  = make_dp
        second = make_dp
        results = DestroyedPost.search(order: "id_asc").to_a
        expect(results.index(first)).to be < results.index(second)
      end
    end
  end
end
