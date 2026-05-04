# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ticket do
  let(:creator)   { create(:user) }
  let(:janitor)   { create(:janitor_user) }
  let(:moderator) { create(:moderator_user) }
  let(:admin)     { create(:admin_user) }
  let(:other)     { create(:user) }

  before do
    CurrentUser.user    = creator
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  # -------------------------------------------------------------------------
  # Blip tickets
  # -------------------------------------------------------------------------
  describe "blip ticket" do
    let(:blip) { create(:blip) }
    let(:ticket) { create(:ticket, :blip_type, blip: blip) }

    describe "#can_create_for?" do
      it "returns true when the blip is visible to the user" do
        expect(ticket.can_create_for?(other)).to be true
      end

      it "returns false when the blip is deleted and the user is a regular member" do
        blip.update_columns(is_deleted: true)
        expect(ticket.can_create_for?(other)).to be false
      end
    end

    describe "#can_view?" do
      it "allows the creator to view" do
        expect(ticket.can_view?(creator)).to be true
      end

      it "allows a janitor to view" do
        expect(ticket.can_view?(janitor)).to be true
      end

      it "allows a moderator to view" do
        expect(ticket.can_view?(moderator)).to be true
      end

      it "allows an admin to view" do
        expect(ticket.can_view?(admin)).to be true
      end

      it "denies a non-creator member" do
        expect(ticket.can_view?(other)).to be false
      end

      context "when the content no longer exists" do
        let(:fresh_ticket) { Ticket.find(ticket.id) }

        before do
          ticket
          blip.destroy!
        end

        it "allows the creator to view" do
          expect(fresh_ticket.can_view?(creator)).to be true
        end

        it "allows a janitor to view" do
          expect(fresh_ticket.can_view?(janitor)).to be true
        end

        it "allows an admin to view" do
          expect(fresh_ticket.can_view?(admin)).to be true
        end

        it "denies a non-creator member" do
          expect(fresh_ticket.can_view?(other)).to be false
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # Comment tickets
  # -------------------------------------------------------------------------
  describe "comment ticket" do
    let(:comment) { create(:comment) }
    let(:ticket)  { create(:ticket, :comment_type, comment: comment) }

    describe "#can_create_for?" do
      it "returns true when the comment is accessible" do
        expect(ticket.can_create_for?(other)).to be true
      end

      it "returns false when the comment is hidden and user is not staff" do
        comment.update_columns(is_hidden: true)
        expect(ticket.can_create_for?(other)).to be false
      end
    end

    describe "#can_view?" do
      it "allows the creator to view" do
        expect(ticket.can_view?(creator)).to be true
      end

      it "allows a janitor to view" do
        expect(ticket.can_view?(janitor)).to be true
      end

      it "allows a moderator to view" do
        expect(ticket.can_view?(moderator)).to be true
      end

      it "allows an admin to view" do
        expect(ticket.can_view?(admin)).to be true
      end

      it "denies a non-creator member" do
        expect(ticket.can_view?(other)).to be false
      end

      context "when the content no longer exists" do
        let(:fresh_ticket) { Ticket.find(ticket.id) }

        before do
          ticket
          comment.destroy!
        end

        it "allows the creator to view" do
          expect(fresh_ticket.can_view?(creator)).to be true
        end

        it "allows a janitor to view" do
          expect(fresh_ticket.can_view?(janitor)).to be true
        end

        it "allows an admin to view" do
          expect(fresh_ticket.can_view?(admin)).to be true
        end

        it "denies a non-creator member" do
          expect(fresh_ticket.can_view?(other)).to be false
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # Dmail tickets — creator must be the dmail recipient
  # -------------------------------------------------------------------------
  describe "dmail ticket" do
    let(:dmail) { create(:dmail, to: creator) }
    let(:ticket) do
      t = build(:ticket, :dmail_type, dmail: dmail)
      t.creator_id      = CurrentUser.id
      t.creator_ip_addr = CurrentUser.ip_addr
      t.save!(validate: false)
      t
    end

    describe "#can_create_for?" do
      it "returns true when the user is the dmail recipient" do
        expect(ticket.can_create_for?(creator)).to be true
      end

      it "returns false when the user is not the dmail recipient" do
        expect(ticket.can_create_for?(other)).to be false
      end
    end

    describe "#can_view?" do
      it "allows the creator to view" do
        expect(ticket.can_view?(creator)).to be true
      end

      it "allows a moderator to view" do
        expect(ticket.can_view?(moderator)).to be true
      end

      it "allows an admin to view (level >= moderator)" do
        expect(ticket.can_view?(admin)).to be true
      end

      it "denies a janitor who is not the creator" do
        expect(ticket.can_view?(janitor)).to be false
      end

      it "denies a non-creator member" do
        expect(ticket.can_view?(other)).to be false
      end

      context "when the content no longer exists" do
        let(:fresh_ticket) { Ticket.find(ticket.id) }

        before do
          ticket
          dmail.destroy!
        end

        it "allows the creator to view" do
          expect(fresh_ticket.can_view?(creator)).to be true
        end

        it "allows a moderator to view" do
          expect(fresh_ticket.can_view?(moderator)).to be true
        end

        it "allows an admin to view" do
          expect(fresh_ticket.can_view?(admin)).to be true
        end

        it "denies a non-creator member" do
          expect(fresh_ticket.can_view?(other)).to be false
        end

        it "denies a janitor who is not the creator" do
          expect(fresh_ticket.can_view?(janitor)).to be false
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # Forum tickets
  # -------------------------------------------------------------------------
  describe "forum ticket" do
    let(:ticket) { create(:ticket, :forum_type) }

    describe "#can_create_for?" do
      it "returns true when the forum post is visible" do
        expect(ticket.can_create_for?(other)).to be true
      end
    end

    describe "#can_view?" do
      it "allows the creator to view" do
        expect(ticket.can_view?(creator)).to be true
      end

      it "allows a janitor to view" do
        expect(ticket.can_view?(janitor)).to be true
      end

      it "allows a moderator to view" do
        expect(ticket.can_view?(moderator)).to be true
      end

      it "allows an admin to view" do
        expect(ticket.can_view?(admin)).to be true
      end

      it "denies a non-creator member" do
        expect(ticket.can_view?(other)).to be false
      end

      context "when the content no longer exists" do
        let(:fresh_ticket) { Ticket.find(ticket.id) }

        before do
          ticket
          ticket.content.destroy!
        end

        it "allows the creator to view" do
          expect(fresh_ticket.can_view?(creator)).to be true
        end

        it "allows a janitor to view" do
          expect(fresh_ticket.can_view?(janitor)).to be true
        end

        it "allows an admin to view" do
          expect(fresh_ticket.can_view?(admin)).to be true
        end

        it "denies a non-creator member" do
          expect(fresh_ticket.can_view?(other)).to be false
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # Pool tickets
  # -------------------------------------------------------------------------
  describe "pool ticket" do
    let(:ticket) { create(:ticket, :pool_type) }

    describe "#can_create_for?" do
      it "returns true for any user" do
        expect(ticket.can_create_for?(other)).to be true
      end
    end

    describe "#can_view?" do
      it "allows the creator to view" do
        expect(ticket.can_view?(creator)).to be true
      end

      it "allows a janitor to view" do
        expect(ticket.can_view?(janitor)).to be true
      end

      it "allows a moderator to view" do
        expect(ticket.can_view?(moderator)).to be true
      end

      it "allows an admin to view" do
        expect(ticket.can_view?(admin)).to be true
      end

      it "denies a non-creator member" do
        expect(ticket.can_view?(other)).to be false
      end
    end
  end

  # -------------------------------------------------------------------------
  # Post tickets
  # -------------------------------------------------------------------------
  describe "post ticket" do
    let(:ticket) { create(:ticket, :post_type) }

    describe "#can_create_for?" do
      it "returns true for any user" do
        expect(ticket.can_create_for?(other)).to be true
      end
    end

    describe "#can_view?" do
      it "allows the creator to view" do
        expect(ticket.can_view?(creator)).to be true
      end

      it "allows a janitor to view" do
        expect(ticket.can_view?(janitor)).to be true
      end

      it "allows a moderator to view" do
        expect(ticket.can_view?(moderator)).to be true
      end

      it "allows an admin to view" do
        expect(ticket.can_view?(admin)).to be true
      end

      it "denies a non-creator member" do
        expect(ticket.can_view?(other)).to be false
      end
    end
  end

  # -------------------------------------------------------------------------
  # Set tickets
  # -------------------------------------------------------------------------
  describe "set ticket" do
    let(:public_set) { create(:post_set, is_public: true) }
    let(:private_set) { create(:post_set, is_public: false) }

    describe "#can_create_for?" do
      it "returns true when the set is public" do
        ticket = build(:ticket, :set_type, post_set: public_set)
        expect(ticket.can_create_for?(other)).to be true
      end

      it "returns false when the set is private and the user is not the owner" do
        ticket = build(:ticket, :set_type, post_set: private_set)
        expect(ticket.can_create_for?(other)).to be false
      end
    end

    describe "#can_view?" do
      let(:ticket) do
        t = build(:ticket, :set_type, post_set: public_set)
        t.creator_id      = CurrentUser.id
        t.creator_ip_addr = CurrentUser.ip_addr
        t.save!(validate: false)
        t
      end

      it "allows the creator to view" do
        expect(ticket.can_view?(creator)).to be true
      end

      it "allows a janitor to view when the set is visible" do
        expect(ticket.can_view?(janitor)).to be true
      end

      it "allows a moderator to view" do
        expect(ticket.can_view?(moderator)).to be true
      end

      it "allows an admin to view" do
        expect(ticket.can_view?(admin)).to be true
      end

      it "denies a non-creator member" do
        expect(ticket.can_view?(other)).to be false
      end

      context "when the content no longer exists" do
        let(:fresh_ticket) { Ticket.find(ticket.id) }

        before do
          ticket
          public_set.destroy!
        end

        it "allows the creator to view" do
          expect(fresh_ticket.can_view?(creator)).to be true
        end

        it "allows a janitor to view" do
          expect(fresh_ticket.can_view?(janitor)).to be true
        end

        it "allows an admin to view" do
          expect(fresh_ticket.can_view?(admin)).to be true
        end

        it "denies a non-creator member" do
          expect(fresh_ticket.can_view?(other)).to be false
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # User tickets
  # -------------------------------------------------------------------------
  describe "user ticket" do
    let(:ticket) { create(:ticket) }

    describe "#can_create_for?" do
      it "returns true for any user" do
        expect(ticket.can_create_for?(other)).to be true
      end
    end

    describe "#can_view?" do
      it "allows the creator to view" do
        expect(ticket.can_view?(creator)).to be true
      end

      it "allows a moderator to view" do
        expect(ticket.can_view?(moderator)).to be true
      end

      it "allows an admin to view (level >= moderator)" do
        expect(ticket.can_view?(admin)).to be true
      end

      it "denies a janitor who is not the creator" do
        expect(ticket.can_view?(janitor)).to be false
      end

      it "denies a non-creator member" do
        expect(ticket.can_view?(other)).to be false
      end
    end
  end

  # -------------------------------------------------------------------------
  # Wiki tickets
  # -------------------------------------------------------------------------
  describe "wiki ticket" do
    let(:ticket) { create(:ticket, :wiki_type) }

    describe "#can_create_for?" do
      it "returns true for any user" do
        expect(ticket.can_create_for?(other)).to be true
      end
    end

    describe "#can_view?" do
      it "allows the creator to view" do
        expect(ticket.can_view?(creator)).to be true
      end

      it "allows a janitor to view" do
        expect(ticket.can_view?(janitor)).to be true
      end

      it "allows a moderator to view" do
        expect(ticket.can_view?(moderator)).to be true
      end

      it "allows an admin to view" do
        expect(ticket.can_view?(admin)).to be true
      end

      it "denies a non-creator member" do
        expect(ticket.can_view?(other)).to be false
      end
    end
  end

  # -------------------------------------------------------------------------
  # Replacement tickets
  # -------------------------------------------------------------------------
  describe "replacement ticket" do
    let(:ticket) { create(:ticket, :replacement_type) }

    describe "#can_create_for?" do
      it "returns true when the replacement is visible (not rejected)" do
        expect(ticket.can_create_for?(other)).to be true
      end

      it "returns false when the replacement is rejected" do
        ticket.content.update_columns(status: "rejected")
        expect(ticket.can_create_for?(other)).to be false
      end
    end

    describe "#can_view?" do
      it "allows the creator to view" do
        expect(ticket.can_view?(creator)).to be true
      end

      it "allows a janitor to view" do
        expect(ticket.can_view?(janitor)).to be true
      end

      it "allows a moderator to view (level >= janitor)" do
        expect(ticket.can_view?(moderator)).to be true
      end

      it "allows an admin to view (level >= janitor)" do
        expect(ticket.can_view?(admin)).to be true
      end

      it "denies a non-creator member" do
        expect(ticket.can_view?(other)).to be false
      end

      context "when the content no longer exists" do
        let(:fresh_ticket) { Ticket.find(ticket.id) }

        before do
          ticket
          ticket.content.destroy!
        end

        it "allows the creator to view" do
          expect(fresh_ticket.can_view?(creator)).to be true
        end

        it "allows a janitor to view" do
          expect(fresh_ticket.can_view?(janitor)).to be true
        end

        it "allows an admin to view" do
          expect(fresh_ticket.can_view?(admin)).to be true
        end

        it "denies a non-creator member" do
          expect(fresh_ticket.can_view?(other)).to be false
        end
      end
    end
  end
end
