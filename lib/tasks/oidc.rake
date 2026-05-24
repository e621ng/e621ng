# frozen_string_literal: true

namespace :oidc do
  desc "Generate an RSA 2048 signing key for the OIDC provider at ~/.danbooru/oidc_signing_key"
  task generate_key: :environment do
    require "fileutils"
    require "openssl"

    path = File.expand_path("~/.danbooru/oidc_signing_key")
    if File.exist?(path)
      abort "Refusing to overwrite existing key at #{path}. Delete it first if you intend to rotate."
    end

    FileUtils.mkdir_p(File.dirname(path), mode: 0o700)
    File.write(path, OpenSSL::PKey::RSA.new(2048).to_pem)
    File.chmod(0o600, path)
    puts "Wrote OIDC signing key to #{path}"
  end
end
