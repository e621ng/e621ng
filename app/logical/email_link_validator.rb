# frozen_string_literal: true

class EmailLinkValidator
  def self.generate(message, purpose, expires = nil)

    validator.generate(message, purpose: purpose, expires_in: expires)
  end

  def self.validate(hash, purpose)
    begin
      message = validator.verify(hash, purpose: purpose)
      return false if message.nil?
      return message
    rescue
      return false
    end
  end

  private

  def self.validator
    @validator ||= ActiveSupport::MessageVerifier.new(Danbooru.config.email_key, serializer: JSON, digest: "SHA256")
  end
end
