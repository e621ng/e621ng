# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pbkdf2 do
  describe ".create_hash" do
    subject(:hash) { described_class.create_hash("password") }

    it "returns a string with exactly 4 colon-separated sections" do
      expect(hash.split(":").length).to eq(4)
    end

    it "uses sha1 as the algorithm identifier" do
      expect(hash.split(":")[0]).to eq("sha1")
    end

    it "encodes the current iteration count" do
      expect(hash.split(":")[described_class::ITERATIONS_INDEX]).to eq(described_class::PBKDF2_ITERATIONS.to_s)
    end

    it "includes a valid Base64-encoded salt" do
      salt = hash.split(":")[described_class::SALT_INDEX]
      expect { Base64.decode64(salt) }.not_to raise_error
      expect(salt).not_to be_empty
    end

    it "includes a valid Base64-encoded hash" do
      hash_value = hash.split(":")[described_class::HASH_INDEX]
      expect { Base64.decode64(hash_value) }.not_to raise_error
      expect(hash_value).not_to be_empty
    end

    it "produces different hashes on successive calls due to random salt" do
      hash2 = described_class.create_hash("password")
      expect(hash).not_to eq(hash2)
    end
  end

  describe ".validate_password" do
    let(:password) { "correct horse battery staple" }
    let(:stored_hash) { described_class.create_hash(password) }

    it "returns true when the password matches the stored hash" do
      expect(described_class.validate_password(password, stored_hash)).to be true
    end

    it "returns false when the password does not match" do
      expect(described_class.validate_password("wrong password", stored_hash)).to be false
    end

    it "is case-sensitive" do
      expect(described_class.validate_password(password.upcase, stored_hash)).to be false
    end

    it "returns false when the hash has fewer than 4 sections" do
      expect(described_class.validate_password(password, "sha1:20000:onlythree")).to be false
    end

    it "returns false when the hash has more than 4 sections" do
      expect(described_class.validate_password(password, "sha1:20000:salt:hash:extra")).to be false
    end
  end

  describe ".needs_upgrade" do
    let(:current_hash) { described_class.create_hash("password") }

    it "returns false for a hash produced with current settings" do
      expect(described_class.needs_upgrade(current_hash)).to be false
    end

    it "returns true when the iteration count differs from PBKDF2_ITERATIONS" do
      old_hash = current_hash.sub(":#{described_class::PBKDF2_ITERATIONS}:", ":10000:")
      expect(described_class.needs_upgrade(old_hash)).to be true
    end

    it "returns true when the hash has fewer than 4 sections" do
      expect(described_class.needs_upgrade("sha1:20000:onlythree")).to be true
    end

    it "returns true when the hash has more than 4 sections" do
      expect(described_class.needs_upgrade("sha1:20000:salt:hash:extra")).to be true
    end
  end
end
