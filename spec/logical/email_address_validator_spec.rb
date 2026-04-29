# frozen_string_literal: true

require "rails_helper"

# Tests every rule enforced by EmailAddressValidator#validate_each.
# The validator is declared on User with:
#   validates :email, email_address: true, if: :enable_email_verification?
# where enable_email_verification? requires both Danbooru.config.enable_email_verification?
# and the User#validate_email_format virtual attribute to be truthy.
#
# Tests run against a real User record because the validator reads
# @email_had_display_name set by the normalize_email_address before_validation
# callback, making a dummy model impractical.

RSpec.describe EmailAddressValidator do
  before do
    allow(Danbooru.config.custom_configuration).to receive(:enable_email_verification?).and_return(true)
  end

  def build_with_email(email)
    build(:user, email: email, validate_email_format: true)
  end

  def errors_for(email)
    user = build_with_email(email)
    user.valid?
    user.errors[:email]
  end

  describe "valid emails" do
    it "accepts a standard address" do
      expect(build_with_email("valid@example.com")).to be_valid
    end

    it "accepts a subdomain" do
      expect(build_with_email("user@mail.example.com")).to be_valid
    end

    it "accepts plus-addressing" do
      expect(build_with_email("user+tag@example.com")).to be_valid
    end

    it "accepts dots in the local part" do
      expect(build_with_email("first.last@example.com")).to be_valid
    end

    it "accepts a long multi-letter TLD" do
      expect(build_with_email("user@example.museum")).to be_valid
    end

    it "accepts a local part of exactly 64 characters" do
      expect(build_with_email("#{'a' * 64}@example.com")).to be_valid
    end

    it "accepts a domain label of exactly 63 characters" do
      expect(build_with_email("user@#{'a' * 63}.com")).to be_valid
    end
  end

  describe "blank email" do
    it "does not add an email_address-specific error for a blank value" do
      user = build_with_email("")
      user.valid?
      validator_messages = [
        "is invalid",
        "cannot have dots at the beginning or end of the local part",
        "cannot have consecutive dots in the local part",
        "local part is too long",
        "domain is too long",
        "must use a standard domain format",
        "has an invalid domain structure",
        "has a domain label that is too long",
        "has a domain label that starts or ends with a hyphen",
        "has invalid characters in the domain",
        "has an invalid top-level domain",
      ]
      expect(user.errors[:email] & validator_messages).to be_empty
    end
  end

  describe "malformed input" do
    it "is invalid when the address has no @ sign" do
      expect(errors_for("notanemail")).to include("is invalid")
    end
  end

  describe "display names" do
    it "is invalid when a display name is included" do
      expect(errors_for("John Doe <john@example.com>")).to include("is invalid")
    end
  end

  describe "local part" do
    describe "leading or trailing dots" do
      it "is invalid when the local part starts with a dot" do
        expect(errors_for(".user@example.com")).to include("cannot have dots at the beginning or end of the local part")
      end

      it "is invalid when the local part ends with a dot" do
        expect(errors_for("user.@example.com")).to include("cannot have dots at the beginning or end of the local part")
      end
    end

    describe "consecutive dots" do
      it "is invalid with consecutive dots in the local part" do
        expect(errors_for("us..er@example.com")).to include("cannot have consecutive dots in the local part")
      end
    end

    describe "length" do
      it "is invalid when the local part exceeds 64 characters" do
        expect(errors_for("#{'a' * 65}@example.com")).to include("local part is too long (maximum 64 characters)")
      end
    end
  end

  describe "domain part" do
    describe "total length" do
      it "is invalid when the domain exceeds 253 characters" do
        # 51 chars × 5 labels + 3 for "com" = 258-char domain, exceeding the 253-char limit
        prefix = "#{'a' * 50}."
        long_domain = "#{prefix * 5}com"
        expect(errors_for("user@#{long_domain}")).to include("domain is too long (maximum 253 characters)")
      end
    end

    describe "IP literals and missing dot" do
      it "is invalid for an IP literal domain" do
        expect(errors_for("user@[127.0.0.1]")).to include("must use a standard domain format")
      end

      it "is invalid when the domain has no dot" do
        expect(errors_for("user@localhost")).to include("must use a standard domain format")
      end
    end

    describe "domain labels" do
      it "is invalid when a label is empty (consecutive dots in domain)" do
        expect(errors_for("user@exam..ple.com")).to include("has an invalid domain structure")
      end

      it "is invalid when a label exceeds 63 characters" do
        expect(errors_for("user@#{'a' * 64}.com")).to include("has a domain label that is too long")
      end

      it "is invalid when a label starts with a hyphen" do
        expect(errors_for("user@-example.com")).to include("has a domain label that starts or ends with a hyphen")
      end

      it "is invalid when a label ends with a hyphen" do
        expect(errors_for("user@example-.com")).to include("has a domain label that starts or ends with a hyphen")
      end

      it "is invalid when a label contains an underscore" do
        expect(errors_for("user@my_domain.com")).to include("has invalid characters in the domain")
      end
    end

    describe "TLD" do
      it "is invalid with a single-character TLD" do
        expect(errors_for("user@example.c")).to include("has an invalid top-level domain")
      end

      it "is invalid with a numeric TLD" do
        expect(errors_for("user@example.123")).to include("has an invalid top-level domain")
      end
    end
  end
end
