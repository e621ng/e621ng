# frozen_string_literal: true

require "rails_helper"

RSpec.describe OidcSigningKey do
  let(:pem) { OpenSSL::PKey::RSA.new(2048).to_pem }

  before do
    described_class.instance_variable_set(:@pem, nil)
    described_class.instance_variable_set(:@private_key, nil)
  end

  after do
    described_class.instance_variable_set(:@pem, nil)
    described_class.instance_variable_set(:@private_key, nil)
  end

  describe ".pem" do
    context "when OIDC_SIGNING_KEY env var is set" do
      it "returns the env var value" do
        ENV["OIDC_SIGNING_KEY"] = pem
        expect(described_class.pem).to eq(pem)
      ensure
        ENV.delete("OIDC_SIGNING_KEY")
      end
    end

    context "when env var is blank, falls back to the on-disk path" do
      before do
        ENV.delete("OIDC_SIGNING_KEY")
        allow(File).to receive(:read).with(described_class.path).and_return(pem)
      end

      it "reads the PEM from the path" do
        expect(described_class.pem).to eq(pem)
      end
    end
  end

  describe ".private_key" do
    it "parses the PEM into an OpenSSL key" do
      allow(described_class).to receive(:pem).and_return(pem)
      expect(described_class.private_key).to be_a(OpenSSL::PKey::RSA)
    end
  end

  describe ".check!" do
    context "with OIDC_SIGNING_KEY set" do
      it "returns without checking the file" do
        ENV["OIDC_SIGNING_KEY"] = pem
        expect(File).not_to receive(:exist?)
        expect { described_class.check! }.not_to raise_error
      ensure
        ENV.delete("OIDC_SIGNING_KEY")
      end
    end

    context "with no env var and no key file" do
      before do
        ENV.delete("OIDC_SIGNING_KEY")
        allow(File).to receive(:exist?).with(described_class.path).and_return(false)
      end

      it "raises a helpful error" do
        expect { described_class.check! }.to raise_error(/OIDC signing key missing/)
      end
    end

    context "when the configured key is too weak" do
      it "raises a key-strength error for a 1024-bit RSA key" do
        weak_pem = OpenSSL::PKey::RSA.new(1024).to_pem
        ENV["OIDC_SIGNING_KEY"] = weak_pem
        expect { described_class.check! }.to raise_error(/too weak: 1024-bit/)
      ensure
        ENV.delete("OIDC_SIGNING_KEY")
      end
    end

    context "when the configured key isn't RSA" do
      it "raises a wrong-algorithm error" do
        ec_pem = OpenSSL::PKey::EC.generate("prime256v1").to_pem
        ENV["OIDC_SIGNING_KEY"] = ec_pem
        expect { described_class.check! }.to raise_error(/must be RSA/)
      ensure
        ENV.delete("OIDC_SIGNING_KEY")
      end
    end

    context "production guard against the committed demo key" do
      # The committed demo key in docker-compose.yml is the canonical source
      # of the fingerprint OidcSigningKey::DEV_KEY_FINGERPRINT recognizes.
      let(:demo_pem) do
        compose = Rails.root.join("docker-compose.yml").read
        pem = compose[/-----BEGIN RSA PRIVATE KEY-----.*?-----END RSA PRIVATE KEY-----/m]
        pem&.gsub(/^ {4}/, "")
      end

      before do
        skip "demo key not embedded in compose file" unless demo_pem&.include?("PRIVATE KEY")
        ENV["OIDC_SIGNING_KEY"] = demo_pem
        described_class.instance_variable_set(:@pem, nil)
        described_class.instance_variable_set(:@private_key, nil)
      end

      after { ENV.delete("OIDC_SIGNING_KEY") }

      it "refuses to boot when the key matches the demo fingerprint" do
        allow(Rails.env).to receive(:production?).and_return(true)
        expect { described_class.check! }.to raise_error(/matches the public demo key/)
      end

      it "boots fine with the demo key outside production (dev/test)" do
        expect(Rails.env.production?).to be false
        expect { described_class.check! }.not_to raise_error
      end
    end

    context "when the configured key is not parseable" do
      it "raises a PEM-parse error" do
        ENV["OIDC_SIGNING_KEY"] = "not a key"
        expect { described_class.check! }.to raise_error(/not a valid PEM-encoded key/)
      ensure
        ENV.delete("OIDC_SIGNING_KEY")
      end
    end

    context "when the key file is world-readable" do
      let(:stat) { instance_double(File::Stat, world_readable?: 0o004, world_writable?: false) }

      before do
        ENV.delete("OIDC_SIGNING_KEY")
        allow(File).to receive(:exist?).with(described_class.path).and_return(true)
        allow(File).to receive(:stat).with(described_class.path).and_return(stat)
      end

      it "raises a permissions error" do
        expect { described_class.check! }.to raise_error(/world readable or writable/)
      end
    end
  end
end
