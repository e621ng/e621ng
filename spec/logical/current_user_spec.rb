# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                              CurrentUser                                    #
# --------------------------------------------------------------------------- #

RSpec.describe CurrentUser do
  # Clean up any state set directly by examples (scoped/as_system clean up
  # themselves via ensure, but accessor tests set state without a scope).
  after do
    CurrentUser.user    = nil
    CurrentUser.api_key = nil
    CurrentUser.ip_addr = nil
    CurrentUser.safe_mode = nil
  end

  # -------------------------------------------------------------------------
  # Accessors
  # -------------------------------------------------------------------------
  describe "accessors" do
    describe ".user / .user=" do
      it "stores and retrieves a user" do
        user = build(:user)
        CurrentUser.user = user
        expect(CurrentUser.user).to be(user)
      end

      it "returns nil when not set" do
        expect(CurrentUser.user).to be_nil
      end
    end

    describe ".api_key / .api_key=" do
      it "stores and retrieves an api key" do
        key = Object.new
        CurrentUser.api_key = key
        expect(CurrentUser.api_key).to be(key)
      end

      it "returns nil when not set" do
        expect(CurrentUser.api_key).to be_nil
      end
    end

    describe ".ip_addr / .ip_addr=" do
      it "stores and retrieves an ip address" do
        CurrentUser.ip_addr = "192.0.2.1"
        expect(CurrentUser.ip_addr).to eq("192.0.2.1")
      end

      it "returns nil when not set" do
        expect(CurrentUser.ip_addr).to be_nil
      end
    end

    describe ".safe_mode? / .safe_mode=" do
      it "returns true when set to true" do
        CurrentUser.safe_mode = true
        expect(CurrentUser.safe_mode?).to be(true)
      end

      it "returns false when set to false" do
        CurrentUser.safe_mode = false
        expect(CurrentUser.safe_mode?).to be(false)
      end

      it "returns nil when not set" do
        expect(CurrentUser.safe_mode?).to be_nil
      end
    end

    describe ".id" do
      it "returns nil when user is nil" do
        expect(CurrentUser.id).to be_nil
      end

      it "returns user.id when a user is set" do
        user = create(:user)
        CurrentUser.user = user
        expect(CurrentUser.id).to eq(user.id)
      end
    end

    describe ".name" do
      it "delegates to user.name" do
        user = create(:user)
        CurrentUser.user = user
        expect(CurrentUser.name).to eq(user.name)
      end
    end
  end

  # -------------------------------------------------------------------------
  # .scoped
  # -------------------------------------------------------------------------
  describe ".scoped" do
    it "sets user and ip_addr for the duration of the block" do
      user = create(:user)
      CurrentUser.scoped(user, "10.0.0.1") do
        expect(CurrentUser.user).to be(user)
        expect(CurrentUser.ip_addr).to eq("10.0.0.1")
      end
    end

    it "uses '127.0.0.1' as the default ip_addr" do
      user = create(:user)
      CurrentUser.scoped(user) do
        expect(CurrentUser.ip_addr).to eq("127.0.0.1")
      end
    end

    it "restores the previous user after the block" do
      outer = create(:user)
      inner = create(:user)
      CurrentUser.user = outer
      CurrentUser.scoped(inner) { nil }
      expect(CurrentUser.user).to be(outer)
    end

    it "restores the previous ip_addr after the block" do
      user = create(:user)
      CurrentUser.ip_addr = "1.2.3.4"
      CurrentUser.scoped(user, "9.9.9.9") { nil }
      expect(CurrentUser.ip_addr).to eq("1.2.3.4")
    end

    it "restores previous values even when the block raises" do
      outer = create(:user)
      inner = create(:user)
      CurrentUser.user    = outer
      CurrentUser.ip_addr = "1.2.3.4"
      begin
        CurrentUser.scoped(inner, "9.9.9.9") { raise "boom" }
      rescue RuntimeError
        nil
      end
      expect(CurrentUser.user).to be(outer)
      expect(CurrentUser.ip_addr).to eq("1.2.3.4")
    end

    it "supports nested scoped calls" do
      a = create(:user)
      b = create(:user)
      c = create(:user)
      CurrentUser.user = a
      CurrentUser.scoped(b) do
        expect(CurrentUser.user).to be(b)
        CurrentUser.scoped(c) do
          expect(CurrentUser.user).to be(c)
        end
        expect(CurrentUser.user).to be(b)
      end
      expect(CurrentUser.user).to be(a)
    end
  end

  # -------------------------------------------------------------------------
  # .as_system
  # -------------------------------------------------------------------------
  describe ".as_system" do
    it "executes the block as User.system" do
      CurrentUser.as_system do
        expect(CurrentUser.user).to eq(User.system)
      end
    end

    it "restores the previous user after the block" do
      user = create(:user)
      CurrentUser.user = user
      CurrentUser.as_system { nil }
      expect(CurrentUser.user).to be(user)
    end
  end

  # -------------------------------------------------------------------------
  # Method delegation
  # -------------------------------------------------------------------------
  describe "method delegation" do
    it "forwards unknown methods to the underlying user object" do
      user = create(:admin_user)
      CurrentUser.user = user
      expect(CurrentUser.is_admin?).to be(true)
    end

    it "forwards methods with arguments" do
      user = create(:user)
      CurrentUser.user = user
      # can_view_flagger? takes a user_id argument
      expect(CurrentUser.can_view_flagger?(user.id)).to eq(user.can_view_flagger?(user.id))
    end
  end
end
