# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserTotp do
  let(:secret) { "JBSWY3DPEHPK3PXP" }
  let(:user) { create(:user) }
  let(:user_totp) { create(:user_totp, user: user, secret: secret) }

  def code_at(time)
    ROTP::TOTP.new(secret).at(time)
  end

  describe "secret encryption" do
    it "round-trips the secret through the ciphertext column" do
      expect(user_totp.secret_ciphertext).not_to include(secret)
      expect(user_totp.reload.secret).to eq(secret)
    end
  end

  describe "#verify_code!" do
    # Step-aligned instant so drift-window assertions don't depend on where inside
    # the 30-second TOTP step the spec happens to run.
    around { |example| travel_to(Time.zone.at(1_775_000_010), &example) }

    it "accepts the current code" do
      expect(user_totp.verify_code!(code_at(Time.now))).to eq(:totp)
    end

    it "accepts codes from the adjacent ±30 second steps" do
      expect(user_totp.verify_code!(code_at(30.seconds.ago))).to eq(:totp)
      user_totp.update_columns(last_used_step: nil)
      expect(user_totp.verify_code!(code_at(30.seconds.from_now))).to eq(:totp)
    end

    it "rejects codes outside the drift window" do
      expect(user_totp.verify_code!(code_at(70.seconds.ago))).to be_nil
      expect(user_totp.verify_code!(code_at(70.seconds.from_now))).to be_nil
    end

    it "rejects garbage input" do
      expect(user_totp.verify_code!("")).to be_nil
      expect(user_totp.verify_code!("000000")).to be_nil
      expect(user_totp.verify_code!("not-a-code")).to be_nil
    end

    it "rejects a replayed code" do
      code = code_at(Time.now)
      expect(user_totp.verify_code!(code)).to eq(:totp)
      expect(user_totp.verify_code!(code)).to be_nil
    end

    it "ignores whitespace in the code" do
      expect(user_totp.verify_code!(" #{code_at(Time.now).insert(3, ' ')} ")).to eq(:totp)
    end

    context "with backup codes" do
      let!(:backup_codes) { user_totp.regenerate_backup_codes! }

      it "accepts a backup code once and consumes it" do
        expect(user_totp.verify_code!(backup_codes.first)).to eq(:backup_code)
        expect(user_totp.reload.backup_code_digests.size).to eq(9)
        expect(user_totp.verify_code!(backup_codes.first)).to be_nil
      end

      it "accepts a backup code with dashes stripped and case-insensitively" do
        expect(user_totp.verify_code!(backup_codes.last.delete("-").upcase)).to eq(:backup_code)
      end

      it "rejects an unknown backup code" do
        expect(user_totp.verify_code!("0000-0000-0000-0000")).to be_nil
        expect(user_totp.reload.backup_code_digests.size).to eq(10)
      end
    end
  end

  describe "#regenerate_backup_codes!" do
    it "returns 10 formatted codes and stores only digests" do
      codes = user_totp.regenerate_backup_codes!
      expect(codes.size).to eq(10)
      expect(codes).to all(match(/\A\h{4}-\h{4}-\h{4}-\h{4}\z/))
      expect(user_totp.reload.backup_code_digests).to all(match(/\A\h{64}\z/))
      expect(user_totp.backup_code_digests).not_to include(*codes)
    end

    it "replaces existing digests wholesale" do
      old_codes = user_totp.regenerate_backup_codes!
      user_totp.regenerate_backup_codes!
      expect(user_totp.verify_code!(old_codes.first)).to be_nil
    end
  end

  describe "User#password_token" do
    it "keeps the historical formula for users without 2FA" do
      expect(user.password_token).to eq(Zlib.crc32(user.bcrypt_password_hash))
    end

    it "changes when 2FA is enabled and reverts semantics when disabled" do
      before_token = user.password_token
      user_totp
      user.reload
      expect(user.password_token).not_to eq(before_token)
      user.totp.destroy
      expect(user.reload.password_token).to eq(before_token)
    end
  end

  describe "User#totp_enabled?" do
    it "reflects the presence of a totp row" do
      expect(user.totp_enabled?).to be(false)
      user_totp
      expect(user.reload.totp_enabled?).to be(true)
    end
  end
end
