# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           Takedown.search                                   #
# --------------------------------------------------------------------------- #

RSpec.describe Takedown do
  include_context "as admin"

  # All search tests use let! so fixtures exist before the search runs.
  # A second "other" takedown is created for each relevant test to confirm
  # the filter excludes non-matching records.

  def make(overrides = {})
    create(:takedown, **overrides)
  end

  # -------------------------------------------------------------------------
  # source
  # -------------------------------------------------------------------------
  describe "source param" do
    let!(:matching)    { make(source: "ArtistWebsite") }
    let!(:nonmatching) { make(source: "OtherSource") }

    it "returns records whose source matches the pattern" do
      expect(Takedown.search(source: "*ArtistWebsite*")).to include(matching)
    end

    it "excludes records whose source does not match" do
      expect(Takedown.search(source: "*ArtistWebsite*")).not_to include(nonmatching)
    end

    it "is case-insensitive" do
      expect(Takedown.search(source: "*artistwebsite*")).to include(matching)
    end
  end

  # -------------------------------------------------------------------------
  # reason
  # -------------------------------------------------------------------------
  describe "reason param" do
    let!(:matching)    { make(reason: "copyright infringement claim") }
    let!(:nonmatching) { make(reason: "unrelated reason") }

    it "returns records whose reason matches the pattern" do
      expect(Takedown.search(reason: "*copyright*")).to include(matching)
    end

    it "excludes non-matching records" do
      expect(Takedown.search(reason: "*copyright*")).not_to include(nonmatching)
    end
  end

  # -------------------------------------------------------------------------
  # post_id
  # -------------------------------------------------------------------------
  describe "post_id param" do
    let(:post)         { create(:post) }
    let!(:matching)    { create(:takedown_with_post, post: post) }
    let!(:nonmatching) { make }

    it "returns records whose post_ids include the given ID" do
      expect(Takedown.search(post_id: post.id)).to include(matching)
    end

    it "excludes records that do not include the given post ID" do
      expect(Takedown.search(post_id: post.id)).not_to include(nonmatching)
    end
  end

  # -------------------------------------------------------------------------
  # instructions
  # -------------------------------------------------------------------------
  describe "instructions param" do
    let!(:matching)    { make(instructions: "remove all my artwork please") }
    let!(:nonmatching) { make(instructions: "something unrelated") }

    it "returns records whose instructions match the pattern" do
      expect(Takedown.search(instructions: "*artwork*")).to include(matching)
    end

    it "excludes non-matching records" do
      expect(Takedown.search(instructions: "*artwork*")).not_to include(nonmatching)
    end
  end

  # -------------------------------------------------------------------------
  # notes
  # -------------------------------------------------------------------------
  describe "notes param" do
    let!(:matching)    { make.tap { |td| td.update_columns(notes: "internal reviewer note") } }
    let!(:nonmatching) { make.tap { |td| td.update_columns(notes: "other note") } }

    it "returns records whose notes match the pattern" do
      expect(Takedown.search(notes: "*reviewer*")).to include(matching)
    end

    it "excludes non-matching records" do
      expect(Takedown.search(notes: "*reviewer*")).not_to include(nonmatching)
    end
  end

  # -------------------------------------------------------------------------
  # reason_hidden
  # -------------------------------------------------------------------------
  describe "reason_hidden param" do
    let!(:hidden)  { make.tap { |td| td.update_columns(reason_hidden: true) } }
    let!(:visible) { make.tap { |td| td.update_columns(reason_hidden: false) } }

    it "returns only records with reason_hidden = true" do
      expect(Takedown.search(reason_hidden: "true")).to include(hidden)
      expect(Takedown.search(reason_hidden: "true")).not_to include(visible)
    end

    it "returns only records with reason_hidden = false" do
      expect(Takedown.search(reason_hidden: "false")).to include(visible)
      expect(Takedown.search(reason_hidden: "false")).not_to include(hidden)
    end
  end

  # -------------------------------------------------------------------------
  # ip_addr
  # -------------------------------------------------------------------------
  describe "ip_addr param" do
    let!(:matching)    { make.tap { |td| td.update_columns(creator_ip_addr: "192.168.1.50") } }
    let!(:nonmatching) { make.tap { |td| td.update_columns(creator_ip_addr: "10.0.0.1") } }

    it "returns records whose creator_ip_addr is within the given subnet" do
      results = Takedown.search(ip_addr: "192.168.1.0/24")
      expect(results).to include(matching)
      expect(results).not_to include(nonmatching)
    end

    it "returns a record when searching by exact IP" do
      expect(Takedown.search(ip_addr: "192.168.1.50")).to include(matching)
    end
  end

  # -------------------------------------------------------------------------
  # creator filter (via where_user)
  # -------------------------------------------------------------------------
  describe "creator filter" do
    let(:creator_a) { create(:user) }
    let(:creator_b) { create(:user) }
    let!(:td_a) { make.tap { |td| td.update_columns(creator_id: creator_a.id) } }
    let!(:td_b) { make.tap { |td| td.update_columns(creator_id: creator_b.id) } }

    it "filters by creator_id" do
      results = Takedown.search(creator_id: creator_a.id)
      expect(results).to include(td_a)
      expect(results).not_to include(td_b)
    end

    it "filters by creator_name" do
      results = Takedown.search(creator_name: creator_a.name)
      expect(results).to include(td_a)
      expect(results).not_to include(td_b)
    end
  end

  # -------------------------------------------------------------------------
  # email
  # -------------------------------------------------------------------------
  describe "email param" do
    let!(:matching)    { make(email: "artist@example.com") }
    let!(:nonmatching) { make(email: "other@example.com") }

    it "returns records whose email matches the pattern" do
      expect(Takedown.search(email: "*artist*")).to include(matching)
    end

    it "excludes non-matching records" do
      expect(Takedown.search(email: "*artist*")).not_to include(nonmatching)
    end
  end

  # -------------------------------------------------------------------------
  # vericode
  # -------------------------------------------------------------------------
  describe "vericode param" do
    let!(:takedown) { make }

    it "returns a record matching the exact vericode" do
      expect(Takedown.search(vericode: takedown.vericode)).to include(takedown)
    end

    it "does not match a different vericode" do
      other = make
      expect(Takedown.search(vericode: takedown.vericode)).not_to include(other)
    end
  end

  # -------------------------------------------------------------------------
  # status
  # -------------------------------------------------------------------------
  describe "status param" do
    let!(:pending)  { make }
    let!(:approved) { make.tap { |td| td.update_columns(status: "approved") } }

    it "returns only records with the given status" do
      expect(Takedown.search(status: "approved")).to include(approved)
      expect(Takedown.search(status: "approved")).not_to include(pending)
    end

    it "returns pending records when searching for 'pending'" do
      expect(Takedown.search(status: "pending")).to include(pending)
      expect(Takedown.search(status: "pending")).not_to include(approved)
    end
  end

  # -------------------------------------------------------------------------
  # creator_logged_in
  # -------------------------------------------------------------------------
  describe "creator_logged_in param" do
    let(:user) { create(:user) }
    let!(:logged_in) { make.tap { |td| td.update_columns(creator_id: user.id) } }
    let!(:anonymous) { make.tap { |td| td.update_columns(creator_id: nil) } }

    it "returns only records with a creator when truthy" do
      results = Takedown.search(creator_logged_in: "true")
      expect(results).to include(logged_in)
      expect(results).not_to include(anonymous)
    end

    it "returns only records without a creator when falsy" do
      results = Takedown.search(creator_logged_in: "false")
      expect(results).to include(anonymous)
      expect(results).not_to include(logged_in)
    end
  end

  # -------------------------------------------------------------------------
  # order param
  # -------------------------------------------------------------------------
  describe "order param" do
    let!(:first)  { make }
    let!(:second) { make }

    it "orders by id descending by default (newest first)" do
      ids = Takedown.search({}).ids
      expect(ids.index(second.id)).to be < ids.index(first.id)
    end

    it "orders by id ascending when order: 'id_asc'" do
      ids = Takedown.search(order: "id_asc").ids
      expect(ids.index(first.id)).to be < ids.index(second.id)
    end

    it "orders by status ascending when order: 'status'" do
      first.update_columns(status: "approved")
      second.update_columns(status: "pending")
      statuses = Takedown.search(order: "status").map(&:status)
      expect(statuses.index("approved")).to be < statuses.index("pending")
    end

    it "orders by post_count descending when order: 'post_count'" do
      first.update_columns(post_count: 5)
      second.update_columns(post_count: 10)
      ids = Takedown.search(order: "post_count").ids
      expect(ids.index(second.id)).to be < ids.index(first.id)
    end
  end
end
