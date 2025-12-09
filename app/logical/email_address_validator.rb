# frozen_string_literal: true

require "mail"

class EmailAddressValidator < ActiveModel::EachValidator
  def validate_each(rec, attr, value)
    email = value.to_s.strip
    return if email.blank?

    # Parse with Mail::Address
    begin
      parsed = Mail::Address.new(email)
      address = parsed.address
    rescue Mail::Field::ParseError
      rec.errors.add(attr, "is invalid")
      return
    end

    # No display names, comments, etc.
    # Check if normalization detected display names in original input
    if address.nil? || rec.instance_variable_get(:@email_had_display_name)
      rec.errors.add(attr, "is invalid")
      return
    end

    local, domain = address.split("@", 2)
    if local.nil? || domain.nil?
      rec.errors.add(attr, "is invalid")
      return
    end

    # ===== Validating Local Parts ===== #

    # Local-part validations
    if local.start_with?(".") || local.end_with?(".")
      rec.errors.add(attr, "cannot have dots at the beginning or end of the local part")
      return
    end

    if local.include?("..")
      rec.errors.add(attr, "cannot have consecutive dots in the local part")
      return
    end

    if local.length > 64
      rec.errors.add(attr, "local part is too long (maximum 64 characters)")
      return
    end

    # ===== Validating Domain Parts ===== #

    if domain.length > 253
      rec.errors.add(attr, "domain is too long (maximum 253 characters)")
      return
    end

    # Reject IP literals and require at least one dot (standard domain format)
    if domain.start_with?("[") || domain.exclude?(".")
      rec.errors.add(attr, "must use a standard domain format")
      return
    end

    # Check domain labels
    labels = domain.split(".")
    labels.each do |label|
      if label.empty?
        rec.errors.add(attr, "has an invalid domain structure")
        break
      end

      if label.length > 63
        rec.errors.add(attr, "has a domain label that is too long")
        break
      end

      if label.start_with?("-") || label.end_with?("-")
        rec.errors.add(attr, "has a domain label that starts or ends with a hyphen")
        break
      end

      # Require labels to be alphanumeric + hyphens only (no underscores, etc.)
      unless label =~ /\A[a-zA-Z0-9-]+\z/
        rec.errors.add(attr, "has invalid characters in the domain")
        break
      end
    end

    # TLD should be at least 2 characters and all letters
    tld = labels.last
    if tld.nil? || tld.length < 2 || tld !~ /\A[a-zA-Z]+\z/
      rec.errors.add(attr, "has an invalid top-level domain")
    end
  end
end
