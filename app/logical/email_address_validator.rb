# frozen_string_literal: true

require "mail"

class EmailAddressValidator < ActiveModel::EachValidator
  def validate_each(rec, attr, value)
    email = value.to_s.strip
    return if email.blank?

    # The normalize_email_address before_validation callback sets
    # @email_had_display_name when the raw input carried a display name.
    # Coerce to a boolean so a never-set ivar (nil) is treated as "no display
    # name", matching the original validate_each behavior.
    had_display_name = rec.instance_variable_get(:@email_had_display_name) == true
    error = self.class.validation_error(email, had_display_name: had_display_name)
    rec.errors.add(attr, error) if error
  end

  # Class-level predicate so non-ActiveModel callers (e.g. mailers) can ask
  # "is this string a deliverable address?" without building a record. Shares
  # the exact structural checks performed by validate_each so the two paths
  # cannot drift.
  #
  # Unlike the instance validator, this is meant to gate sending mail to a
  # value taken verbatim from the database, so it is stricter:
  #   * the raw value must already be trimmed (leading/trailing whitespace or
  #     CR/LF would survive into the recipient header and make the mail gem
  #     raise at format time, so such values are rejected), and
  #   * any parser failure (not just Mail::Field::ParseError) is treated as
  #     invalid rather than propagated, so the caller can never crash.
  def self.valid?(email)
    raw = email.to_s
    value = raw.strip
    return false if value.blank?
    return false if raw != value

    validation_error(value).nil?
  rescue StandardError
    false
  end

  # Returns an error message (String) describing the first structural problem
  # with +email+, or nil when the address is acceptable. +email+ must already
  # be stripped and non-blank.
  #
  # +had_display_name+ lets the instance validator pass the result of the
  # normalize_email_address callback. When nil (the class-level caller), a
  # display name is detected directly by comparing the parsed address against
  # the input.
  def self.validation_error(email, had_display_name: nil)
    # Parse with Mail::Address
    begin
      parsed = Mail::Address.new(email)
      address = parsed.address
    rescue Mail::Field::ParseError
      return "is invalid"
    end

    return "is invalid" if address.nil?

    # No display names, comments, etc.
    display_name = had_display_name.nil? ? (address != email) : had_display_name
    return "is invalid" if display_name

    local, domain = address.split("@", 2)
    return "is invalid" if local.nil? || domain.nil?

    # ===== Validating Local Parts ===== #

    # Local-part validations
    if local.start_with?(".") || local.end_with?(".")
      return "cannot have dots at the beginning or end of the local part"
    end

    return "cannot have consecutive dots in the local part" if local.include?("..")

    return "local part is too long (maximum 64 characters)" if local.length > 64

    # ===== Validating Domain Parts ===== #

    return "domain is too long (maximum 253 characters)" if domain.length > 253

    # Reject IP literals and require at least one dot (standard domain format)
    if domain.start_with?("[") || domain.exclude?(".")
      return "must use a standard domain format"
    end

    # Check domain labels
    labels = domain.split(".")
    labels.each do |label|
      return "has an invalid domain structure" if label.empty?

      return "has a domain label that is too long" if label.length > 63

      if label.start_with?("-") || label.end_with?("-")
        return "has a domain label that starts or ends with a hyphen"
      end

      # Require labels to be alphanumeric + hyphens only (no underscores, etc.)
      return "has invalid characters in the domain" unless label =~ /\A[a-zA-Z0-9-]+\z/
    end

    # TLD should be at least 2 characters and all letters
    tld = labels.last
    if tld.nil? || tld.length < 2 || tld !~ /\A[a-zA-Z]+\z/
      return "has an invalid top-level domain"
    end

    nil
  end
end
