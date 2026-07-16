# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/fixes/138_clear_deprecated_user_bitflags.rb")

# --------------------------------------------------------------------------- #
#                          User deprecated bit_prefs                          #
# --------------------------------------------------------------------------- #

RSpec.describe User do
  before do
    CurrentUser.user = create(:user)
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user = nil
    CurrentUser.ip_addr = nil
  end

  describe ".deprecated_bit_prefs_mask" do
    it "is the OR of every underscore-prefixed flag and nothing else" do
      deprecated, live = User::BOOLEAN_ATTRIBUTES.partition { |a| a.start_with?("_") }
      expected = deprecated.sum { |a| User.flag_value_for(a) }

      expect(User.deprecated_bit_prefs_mask).to eq(expected)
      live.each do |flag|
        expect(User.deprecated_bit_prefs_mask & User.flag_value_for(flag)).to eq(0)
      end
    end
  end

  describe "ZeroDeprecatedUserBitflags fixer script" do
    subject(:run_migration) { Fixes::ZeroDeprecatedUserBitflags.run }

    let(:mask) { User.deprecated_bit_prefs_mask }

    it "clears a deprecated bit while preserving a live flag on the same user" do
      user = create(:user)
      user.update_columns(bit_prefs: User.flag_value_for("_show_avatars") | User.flag_value_for("enable_safe_mode"))

      run_migration

      user.reload
      expect(user._show_avatars).to be false
      expect(user.enable_safe_mode).to be true
    end

    it "leaves a user with no deprecated bits unchanged" do
      user = create(:user)
      user.update_columns(bit_prefs: User.flag_value_for("enable_safe_mode"))

      expect { run_migration }.not_to(change { user.reload.bit_prefs })
    end

    it "is idempotent" do
      user = create(:user)
      user.update_columns(bit_prefs: User.flag_value_for("_show_avatars"))

      run_migration
      cleaned = user.reload.bit_prefs
      run_migration

      expect(user.reload.bit_prefs).to eq(cleaned)
      expect(user.bit_prefs & mask).to eq(0)
    end
  end
end
