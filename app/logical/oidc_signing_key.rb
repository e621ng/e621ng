# frozen_string_literal: true

module OidcSigningKey
  module_function

  # SHA256 of the public DER of the demo key in docker-compose.yml.
  DEV_KEY_FINGERPRINT = "656acf9546ed4f7e7dadd54f0379833fb6813107d3becb060b63a047531b15c6"

  def pem
    @pem ||= ENV["OIDC_SIGNING_KEY"].presence || File.read(path)
  end

  def private_key
    @private_key ||= OpenSSL::PKey.read(pem)
  end

  def fingerprint
    OpenSSL::Digest::SHA256.hexdigest(private_key.public_to_der)
  end

  def dev_key?
    fingerprint == DEV_KEY_FINGERPRINT
  end

  def path
    File.expand_path("~/.danbooru/oidc_signing_key")
  end

  def check!
    if ENV["OIDC_SIGNING_KEY"].blank?
      unless File.exist?(path)
        raise "OIDC signing key missing. Run `rake oidc:generate_key` or set OIDC_SIGNING_KEY, " \
              "or create #{path} containing a PEM-encoded RSA private key."
      end

      stat = File.stat(path)
      if stat.world_readable? || stat.world_writable?
        raise "#{path} must not be world readable or writable"
      end
    end

    key = begin
      OpenSSL::PKey.read(pem)
    rescue OpenSSL::PKey::PKeyError => e
      raise "OIDC signing key is not a valid PEM-encoded key: #{e.message}"
    end

    unless key.is_a?(OpenSSL::PKey::RSA)
      raise "OIDC signing key must be RSA (got #{key.class})"
    end

    bits = key.n.num_bits
    if bits < 2048
      raise "OIDC signing key is too weak: #{bits}-bit RSA (need at least 2048)"
    end

    if Rails.env.production? && dev_key?
      raise "OIDC signing key matches the public demo key from docker-compose.yml. " \
            "Generate a real key (`rake oidc:generate_key`) before booting in production."
    end
  end
end
