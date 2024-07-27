# frozen_string_literal: true

# Password Hashing With PBKDF2 (http://crackstation.net/hashing-security.htm).
# Copyright (c) 2013, Taylor Hornby
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

require 'securerandom'
require 'openssl'
require 'base64'

module Pbkdf2

  PBKDF2_ITERATIONS = 20000
  SALT_BYTE_SIZE = 24
  HASH_BYTE_SIZE = 24

  HASH_SECTIONS = 4
  SECTION_DELIMITER = ':'
  ITERATIONS_INDEX = 1
  SALT_INDEX = 2
  HASH_INDEX = 3

  def self.create_hash( password )
    salt = SecureRandom.base64( SALT_BYTE_SIZE )
    pbkdf2 = OpenSSL::PKCS5::pbkdf2_hmac_sha1(
        password,
        salt,
        PBKDF2_ITERATIONS,
        HASH_BYTE_SIZE
    )
    return ["sha1", PBKDF2_ITERATIONS, salt, Base64.encode64( pbkdf2 )].join( SECTION_DELIMITER )
  end

  def self.validate_password( password, correctHash )
    params = correctHash.split( SECTION_DELIMITER )
    return false if params.length != HASH_SECTIONS

    pbkdf2 = Base64.decode64( params[HASH_INDEX] )
    testHash = OpenSSL::PKCS5::pbkdf2_hmac_sha1(
        password,
        params[SALT_INDEX],
        params[ITERATIONS_INDEX].to_i,
        pbkdf2.length
    )

    return pbkdf2 == testHash
  end

  def self.needs_upgrade( hash )
    params = hash.split( SECTION_DELIMITER )
    if params.length != HASH_SECTIONS
      return true
    end
    if params[ITERATIONS_INDEX] != PBKDF2_ITERATIONS.to_s
      return true
    end
    return false
  end

end
