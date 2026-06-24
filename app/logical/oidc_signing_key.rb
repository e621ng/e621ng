# frozen_string_literal: true

module OidcSigningKey
  module_function

  def pem
    @pem ||= ENV["OIDC_SIGNING_KEY"].presence || File.read(path)
  rescue Errno::ENOENT
    raise unless defined?(Rails) && Rails.env.test?
    @pem = OpenSSL::PKey::RSA.new(2048).to_pem
  end

  def private_key
    @private_key ||= OpenSSL::PKey.read(pem)
  end

  def path
    File.expand_path("~/.danbooru/oidc_signing_key")
  end

  def check!
    if ENV["OIDC_SIGNING_KEY"].blank?
      unless File.exist?(path)
        raise "OIDC signing key missing. Set OIDC_SIGNING_KEY or create #{path} " \
              "containing a PEM-encoded RSA private key."
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
  end
end
